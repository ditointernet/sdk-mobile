package br.com.dito.ditosdk.tracking

import android.content.Context
import android.provider.Settings
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.EventOff
import br.com.dito.ditosdk.Identify
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
import br.com.dito.ditosdk.utils.formatToISO
import java.util.Date
import java.util.concurrent.TimeUnit

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
        Settings.Secure.putString(context.contentResolver, Settings.Secure.ANDROID_ID, "device-1")
        trackerOffline = mockk(relaxed = true)
        mockClient = mockk<MobileIngestClientInterface>(relaxed = true)
        coEvery { mockClient.activity(any()) } returns Api.Response.getDefaultInstance()
        val mapper = ActivityMapper(context)
        tracker = Tracker(trackerOffline, mockClient, mapper, AnonymousState(context), scope = testScope)
        tracker.id = "user123"
        trackerRetry = TrackerRetry(
            tracker,
            trackerOffline,
            mockClient,
            mapper,
            5,
            testScope,
        )
        tracker.setTrackerRetry(trackerRetry)
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
        val coldTracker = Tracker(trackerOffline, mockClient, mapper, AnonymousState(context), scope = TestScope(trackerScheduler))
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
        val loggedOut = Tracker(trackerOffline, mockClient, ActivityMapper(context), AnonymousState(context), scope = testScope)
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
        pendingIdentify()

        trackerRetry.uploadEvents()
        advanceUntilIdle()

        val resent = requests.single { r -> r.activitiesList.any { it.hasTokenRegister() } }
        assertThat(resent.userId).isEqualTo("user123")
        assertThat(resent.activitiesList.single().tokenRegister.token).isEqualTo("token123")
    }

    @Test
    fun `checkIdentify should not resend the token when the user changed`() = testScope.runTest {
        val requests = captureRequests("device-1")
        AnonymousState(context).lastToken = "token123"
        every { trackerOffline.getIdentify() } returns storedIdentify().copy(send = false)
        tracker.id = "other-user"

        trackerRetry.uploadEvents()
        advanceUntilIdle()

        verify { trackerOffline.updateIdentify("user123", true) }
        assertThat(requests.none { r -> r.activitiesList.any { it.hasTokenRegister() } }).isTrue()
    }

    @Test
    fun `retry without android id should send nothing nor spend attempts, and send all when it comes back`() =
        testScope.runTest {
            val requests = captureRequests("")
            every { trackerOffline.getIdentify() } returns storedIdentify().copy(send = false)
            every { trackerOffline.getAllEvents() } returns listOf(
                EventOff(1, "anon", "x", null, null, "t", 0, anonymous = true),
                EventOff(2, "owned", "y", null, null, "t", 0),
                EventOff(3, "old", "z", null, null, "t", 5),
            )
            every { trackerOffline.getAllNotificationRead() } returns listOf(NotificationReadOff(4, "a4", "n1", "i1", 0))

            trackerRetry.uploadEvents()
            advanceUntilIdle()

            coVerify(exactly = 0) { mockClient.activity(any()) }
            verify(exactly = 0) { trackerOffline.update(any(), any(), any()) }
            // Só o que já esgotou as tentativas sai da fila.
            verify(exactly = 1) { trackerOffline.delete(any(), any()) }
            verify { trackerOffline.delete(3, "Event") }
            verify(exactly = 0) { trackerOffline.updateIdentify(any(), any()) }

            Settings.Secure.putString(context.contentResolver, Settings.Secure.ANDROID_ID, "device-1")
            trackerRetry.uploadEvents()
            advanceUntilIdle()

            assertThat(requests.all { it.device.deviceId == "device-1" }).isTrue()
            verify { trackerOffline.updateIdentify("user123", true) }
            verify { trackerOffline.delete(1, "Event") }
            verify { trackerOffline.delete(2, "Event") }
            verify { trackerOffline.delete(3, "Event") }
            verify { trackerOffline.delete(4, "NotificationRead") }
        }

    @Test
    fun `without android id, queue above the limit should drop the oldest rows without spending attempts`() =
        testScope.runTest {
            captureRequests("")
            val recent = Date().formatToISO()
            every { trackerOffline.getAllEvents() } returns (1..TrackerRetry.MAX_QUEUE_ROWS_WITHOUT_DEVICE_ID + 2)
                .map { EventOff(it, "a$it", "x", null, null, recent, 0) }
                .reversed()
            every { trackerOffline.getAllNotificationRead() } returns
                (1..TrackerRetry.MAX_QUEUE_ROWS_WITHOUT_DEVICE_ID + 1).map { NotificationReadOff(it, "a$it", "n", "i", 0) }

            trackerRetry.uploadEvents()
            advanceUntilIdle()

            verify { trackerOffline.delete(1, "Event") }
            verify { trackerOffline.delete(2, "Event") }
            verify { trackerOffline.delete(1, "NotificationRead") }
            verify(exactly = 3) { trackerOffline.delete(any(), any()) }
            verify(exactly = 0) { trackerOffline.update(any(), any(), any()) }
            coVerify(exactly = 0) { mockClient.activity(any()) }
        }

    @Test
    fun `without android id, events older than the age limit should be dropped`() = testScope.runTest {
        captureRequests("")
        val ageLimit = TimeUnit.DAYS.toMillis(TrackerRetry.MAX_QUEUE_AGE_DAYS_WITHOUT_DEVICE_ID)
        val old = Date(System.currentTimeMillis() - ageLimit - TimeUnit.DAYS.toMillis(1)).formatToISO()
        val recent = Date().formatToISO()
        every { trackerOffline.getAllEvents() } returns listOf(
            EventOff(1, "old", "x", null, null, old, 0, anonymous = true),
            EventOff(2, "recent", "x", null, null, recent, 0),
            EventOff(3, "undated", "x", null, null, "t", 0),
            EventOff(4, "exhausted", "x", null, null, recent, 5),
        )

        trackerRetry.uploadEvents()
        advanceUntilIdle()

        verify { trackerOffline.delete(1, "Event") }
        verify { trackerOffline.delete(4, "Event") }
        verify(exactly = 2) { trackerOffline.delete(any(), any()) }
        verify(exactly = 0) { trackerOffline.update(any(), any(), any()) }
        coVerify(exactly = 0) { mockClient.activity(any()) }
    }

    @Test
    fun `android id showing up should flush the queue and the pending identify without a new upload call`() =
        testScope.runTest {
            val requests = captureRequests("")
            pendingIdentify()
            every { trackerOffline.getAllEvents() } returns listOf(EventOff(1, "a1", "x", null, null, "t", 0))
            trackerRetry.uploadEvents()
            advanceUntilIdle()
            coVerify(exactly = 0) { mockClient.activity(any()) }

            Settings.Secure.putString(context.contentResolver, Settings.Secure.ANDROID_ID, "device-1")
            tracker.notificationClick("n1", "r1", "user123")
            advanceUntilIdle()

            verify { trackerOffline.updateIdentify("user123", true) }
            verify { trackerOffline.delete(1, "Event") }
            assertThat(requests.flatMap { it.activitiesList }.map { it.id }).contains("a1")
        }

    @Test
    fun `android id showing up on a live identify should flush once, after the identify`() = testScope.runTest {
        val requests = captureRequests("")
        every { trackerOffline.getAllEvents() } returns listOf(EventOff(1, "a1", "x", null, null, "t", 0))
        trackerRetry.uploadEvents()
        advanceUntilIdle()

        Settings.Secure.putString(context.contentResolver, Settings.Secure.ANDROID_ID, "device-1")
        tracker.identify(Identify("user123"), null)
        advanceUntilIdle()

        // Uma leitura na poda sem device_id e uma no único flush.
        verify(exactly = 2) { trackerOffline.getAllEvents() }
        assertThat(requests.first().activitiesList.single().hasIdentify()).isTrue()
        assertThat(requests.last().activitiesList.map { it.id }).containsExactly("a1")
    }

    @Test
    fun `android id showing up on a failed live identify should still flush the queue`() = testScope.runTest {
        captureRequests("")
        trackerRetry.uploadEvents()
        advanceUntilIdle()
        coEvery { mockClient.activity(any()) } throws Exception("err")

        Settings.Secure.putString(context.contentResolver, Settings.Secure.ANDROID_ID, "device-1")
        tracker.identify(Identify("user123"), null)
        advanceUntilIdle()

        verify(exactly = 2) { trackerOffline.getAllNotificationRead() }
    }

    /** Identify do disco ainda não enviado, que passa a `send = true` quando o SDK o confirma. */
    private fun pendingIdentify() {
        var stored = storedIdentify().copy(send = false)
        every { trackerOffline.getIdentify() } answers { stored }
        every { trackerOffline.updateIdentify(any(), any()) } answers { stored = stored.copy(send = secondArg()) }
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
