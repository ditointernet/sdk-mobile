package br.com.dito.ditosdk.tracking

import android.content.Context
import android.provider.Settings
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.EventOff
import br.com.dito.ditosdk.IdentifyOff
import br.com.dito.ditosdk.NotificationReadOff
import br.com.dito.ditosdk.service.ActivityMapper
import br.com.dito.ditosdk.service.MobileIngestClientInterface
import com.google.common.truth.Truth.assertThat
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.TestCoroutineScheduler
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.cancel
import mobileingest.v1.Api
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class TrackerRetryTest {

    private val testScope = TestScope()

    /** Scheduler separado, para poder deixar o carregamento do identify pendente. */
    private val trackerScheduler = TestCoroutineScheduler()
    private lateinit var context: Context
    private lateinit var tracker: Tracker
    private lateinit var trackerOffline: TrackerOffline
    private lateinit var trackerRetry: TrackerRetry
    private lateinit var mockClient: MobileIngestClientInterface

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        trackerOffline = mockk(relaxed = true)
        mockClient = mockk<MobileIngestClientInterface>(relaxed = true)
        coEvery { mockClient.activity(any()) } returns Api.Response.getDefaultInstance()
        val mapper = ActivityMapper(context)
        tracker = Tracker(trackerOffline, mockClient, mapper, scope = testScope)
        tracker.id = "user123"
        trackerRetry = TrackerRetry(
            tracker,
            trackerOffline,
            mockClient,
            mapper,
            5,
            testScope,
        )
    }

    @After
    fun tearDown() {
        testScope.cancel()
    }

    @Test
    fun `checkIdentify should update identify when API succeeds`() = testScope.runTest {
        val identifyOff = IdentifyOff(
            id = "user123",
            name = null,
            email = null,
            gender = null,
            birthday = null,
            location = null,
            customDataJson = null,
            send = false,
        )
        every { trackerOffline.getIdentify() } returns identifyOff

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify { trackerOffline.updateIdentify("user123", true) }
    }

    @Test
    fun `checkIdentify should not update when identify is already sent`() = testScope.runTest {
        val identifyOff = IdentifyOff(
            id = "user123",
            name = null,
            email = null,
            gender = null,
            birthday = null,
            location = null,
            customDataJson = null,
            send = true,
        )
        every { trackerOffline.getIdentify() } returns identifyOff

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify(exactly = 0) { trackerOffline.updateIdentify(any(), any()) }
    }

    @Test
    fun `checkEvent should delete event when retry limit reached`() = testScope.runTest {
        val eventOff = EventOff(1, "a1", "x", null, null, "t", 5)
        every { trackerOffline.getAllEvents() } returns listOf(eventOff)

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify { trackerOffline.delete(1, "Event") }
    }

    @Test
    fun `checkEvent should update retry on failure`() = testScope.runTest {
        val eventOff = EventOff(1, "a1", "x", null, null, "t", 0)
        every { trackerOffline.getAllEvents() } returns listOf(eventOff)
        coEvery { mockClient.activity(any()) } throws Exception("fail")

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify { trackerOffline.update(1, 1, "Event") }
    }

    @Test
    fun `checkEvent should delete event on success`() = testScope.runTest {
        val eventOff = EventOff(1, "a1", "x", null, null, "t", 0)
        every { trackerOffline.getAllEvents() } returns listOf(eventOff)

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify { trackerOffline.delete(1, "Event") }
    }

    @Test
    fun `checkNotificationRead should delete notification when retry limit reached`() = testScope.runTest {
        val notificationOff = NotificationReadOff(1, "a1", "n1", "i1", 5)
        every { trackerOffline.getAllNotificationRead() } returns listOf(notificationOff)

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify { trackerOffline.delete(1, "NotificationRead") }
    }

    @Test
    fun `checkNotificationRead should update retry on failure`() = testScope.runTest {
        val notificationOff = NotificationReadOff(1, "a1", "n1", "i1", 0)
        every { trackerOffline.getAllNotificationRead() } returns listOf(notificationOff)
        coEvery { mockClient.activity(any()) } throws Exception("fail")

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify { trackerOffline.update(1, 1, "NotificationRead") }
    }

    @Test
    fun `checkNotificationRead should delete notification on success`() = testScope.runTest {
        val notificationOff = NotificationReadOff(1, "a1", "n1", "i1", 0)
        every { trackerOffline.getAllNotificationRead() } returns listOf(notificationOff)

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify { trackerOffline.delete(1, "NotificationRead") }
    }

    @Test
    fun `checkEvent should drain the queue on cold start, before the identify is loaded`() = testScope.runTest {
        every { trackerOffline.getIdentify() } returns storedIdentify()
        every { trackerOffline.getAllEvents() } returns listOf(EventOff(1, "a1", "x", null, null, "t", 0))
        val coldRetry = coldStartRetry()

        coldRetry.uploadEvents()
        advanceUntilIdle()

        // O flush já correu inteiro com o `id` ainda nulo: é a ordem do cold start pelo push, e é
        // aqui que ele voltava sem drenar nada.
        verify(exactly = 0) { trackerOffline.delete(1, "Event") }

        trackerScheduler.advanceUntilIdle()
        advanceUntilIdle()
        verify { trackerOffline.delete(1, "Event") }
    }

    @Test
    fun `checkNotificationRead should drain the queue on cold start, before the identify is loaded`() =
        testScope.runTest {
            every { trackerOffline.getIdentify() } returns storedIdentify()
            every { trackerOffline.getAllNotificationRead() } returns
                listOf(NotificationReadOff(1, "a1", "n1", "i1", 0))
            val coldRetry = coldStartRetry()

            coldRetry.uploadEvents()
            advanceUntilIdle()

            verify(exactly = 0) { trackerOffline.delete(1, "NotificationRead") }

            trackerScheduler.advanceUntilIdle()
            advanceUntilIdle()
            verify { trackerOffline.delete(1, "NotificationRead") }
        }

    @Test
    fun `checkNotificationRead should resend the action data with the click`() = testScope.runTest {
        val notificationOff = NotificationReadOff(
            1,
            "a1",
            "n1",
            "i1",
            0,
            mapOf("action_id" to "botao_1", "action_label" to "Botão 1"),
        )
        every { trackerOffline.getAllNotificationRead() } returns listOf(notificationOff)
        val request = slot<Api.Request>()
        coEvery { mockClient.activity(capture(request)) } returns Api.Response.getDefaultInstance()

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        val data = request.captured.activitiesList.first { it.hasTrackPushClick() }.trackPushClick.dataMap
        assertThat(data["action_id"]?.single?.stringValue).isEqualTo("botao_1")
        assertThat(data["action_label"]?.single?.stringValue).isEqualTo("Botão 1")
    }

    private fun storedIdentify() = IdentifyOff(
        id = "user123",
        name = null,
        email = null,
        gender = null,
        birthday = null,
        location = null,
        customDataJson = null,
        send = true,
    )

    /**
     * Retry apontando para um `Tracker` cujo carregamento do identify fica pendente num scheduler
     * próprio. Sem isso os dois rodariam no mesmo dispatcher e o identify carregaria primeiro — a
     * ordem oposta à do cold start, que é justamente a que se quer testar.
     */
    private fun coldStartRetry(): TrackerRetry {
        val mapper = ActivityMapper(context)
        val coldTracker = Tracker(trackerOffline, mockClient, mapper, scope = TestScope(trackerScheduler))
        assertThat(coldTracker.idOrNull).isNull()
        return TrackerRetry(coldTracker, trackerOffline, mockClient, mapper, 5, testScope)
    }

    @Test
    fun `anonymous queued event should be sent without waiting for identify`() = testScope.runTest {
        val requests = captureRequests("device-1")
        every { trackerOffline.getAllEvents() } returns listOf(EventOff(1, "a1", "x", null, null, "t", 0, anonymous = true))
        val coldRetry = coldStartRetry()

        coldRetry.uploadEvents()
        advanceUntilIdle()

        verify { trackerOffline.delete(1, "Event") }
        val request = requests.single()
        assertThat(request.userId).isEmpty()
        assertThat(request.activitiesList.first().hasIdentify()).isTrue()
        assertThat(request.activitiesList.last().id).isEqualTo("a1")

        // Libera o identify pendente para o checkNotificationRead terminar.
        trackerScheduler.advanceUntilIdle()
        advanceUntilIdle()
    }

    @Test
    fun `anonymous queued event should stay in the queue without android id`() = testScope.runTest {
        captureRequests("")
        every { trackerOffline.getAllEvents() } returns listOf(EventOff(1, "a1", "x", null, null, "t", 0, anonymous = true))

        trackerRetry.uploadEvents()
        advanceUntilIdle()

        coVerify(exactly = 0) { mockClient.activity(any()) }
        verify(exactly = 0) { trackerOffline.delete(1, "Event") }
        verify(exactly = 0) { trackerOffline.update(1, any(), "Event") }
    }

    @Test
    fun `queued event with owner should wait for login`() = testScope.runTest {
        captureRequests("device-1")
        every { trackerOffline.getAllEvents() } returns listOf(EventOff(1, "a1", "x", null, null, "t", 0))
        val loggedOut = Tracker(trackerOffline, mockClient, ActivityMapper(context), scope = testScope)
        val retry = TrackerRetry(loggedOut, trackerOffline, mockClient, ActivityMapper(context), 5, testScope)

        retry.uploadEvents()
        advanceUntilIdle()

        coVerify(exactly = 0) { mockClient.activity(any()) }
        verify(exactly = 0) { trackerOffline.delete(1, "Event") }
    }

    @Test
    fun `mixed queue should go out in two requests, one per owner`() = testScope.runTest {
        val requests = captureRequests("device-1")
        every { trackerOffline.getAllEvents() } returns listOf(
            EventOff(1, "anon", "x", null, null, "t", 0, anonymous = true),
            EventOff(2, "owned", "y", null, null, "t", 0),
        )

        trackerRetry.uploadEvents()
        advanceUntilIdle()

        assertThat(requests).hasSize(2)
        val anonymous = requests.single { it.userId.isEmpty() }
        assertThat(anonymous.activitiesList.filter { it.hasTrack() }.map { it.id }).containsExactly("anon")
        val owned = requests.single { it.userId == "user123" }
        assertThat(owned.activitiesList.map { it.id }).containsExactly("owned")
        verify { trackerOffline.delete(1, "Event") }
        verify { trackerOffline.delete(2, "Event") }
    }

    @Test
    fun `anonymous queued event should stay anonymous after login`() = testScope.runTest {
        val requests = captureRequests("device-1")
        every { trackerOffline.getAllEvents() } returns listOf(EventOff(1, "a1", "x", null, null, "t", 0, anonymous = true))

        trackerRetry.uploadEvents()
        advanceUntilIdle()

        assertThat(tracker.idOrNull).isEqualTo("user123")
        val request = requests.single()
        assertThat(request.userId).isEmpty()
        assertThat(request.activitiesList.first().hasIdentify()).isTrue()
        verify { trackerOffline.delete(1, "Event") }
    }

    @Test
    fun `concurrent uploads should send the queued batch once`() = testScope.runTest {
        val requests = captureRequests("device-1")
        var queue = listOf(EventOff(1, "a1", "x", null, null, "t", 0, anonymous = true))
        every { trackerOffline.getAllEvents() } answers { queue.takeIf { it.isNotEmpty() } }
        every { trackerOffline.delete(any(), "Event") } answers {
            val id = firstArg<Int>()
            queue = queue.filter { it.id != id }
        }
        coEvery { mockClient.activity(capture(requests)) } coAnswers {
            delay(100)
            Api.Response.getDefaultInstance()
        }

        trackerRetry.uploadEvents()
        trackerRetry.uploadEvents()
        advanceUntilIdle()

        assertThat(requests).hasSize(1)
    }

    @Test
    fun `checkIdentify success should register the last token again`() = testScope.runTest {
        val requests = captureRequests("device-1")
        AnonymousState(context).lastToken = "token123"
        every { trackerOffline.getIdentify() } returns storedIdentify().copy(send = false)

        trackerRetry.uploadEvents()
        advanceUntilIdle()

        val resent = requests.single { r -> r.activitiesList.any { it.hasTokenRegister() } }
        assertThat(resent.userId).isEqualTo("user123")
        assertThat(resent.activitiesList.single().tokenRegister.token).isEqualTo("token123")
    }

    private fun captureRequests(androidId: String): MutableList<Api.Request> {
        Settings.Secure.putString(context.contentResolver, Settings.Secure.ANDROID_ID, androidId)
        every { trackerOffline.getIdentify() } returns null
        every { trackerOffline.getAllEvents() } returns null
        every { trackerOffline.getAllNotificationRead() } returns null
        val requests = mutableListOf<Api.Request>()
        coEvery { mockClient.activity(capture(requests)) } returns Api.Response.getDefaultInstance()
        return requests
    }

    @Test
    fun `uploadEvents should check all types`() = testScope.runTest {
        every { trackerOffline.getIdentify() } returns null
        every { trackerOffline.getAllEvents() } returns null
        every { trackerOffline.getAllNotificationRead() } returns null

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify { trackerOffline.getIdentify() }
        verify { trackerOffline.getAllEvents() }
        verify { trackerOffline.getAllNotificationRead() }
    }
}
