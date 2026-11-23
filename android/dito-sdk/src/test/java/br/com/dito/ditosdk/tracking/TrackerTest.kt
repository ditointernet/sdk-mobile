package br.com.dito.ditosdk.tracking

import android.content.Context
import android.provider.Settings
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.BuildConfig
import br.com.dito.ditosdk.Dito
import br.com.dito.ditosdk.Event
import br.com.dito.ditosdk.Identify
import br.com.dito.ditosdk.IdentifyOff
import br.com.dito.ditosdk.service.ActivityMapper
import br.com.dito.ditosdk.service.MobileIngestClientInterface
import com.google.common.truth.Truth.assertThat
import io.mockk.clearMocks
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.delay
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
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class TrackerTest {

    private val testScope = TestScope()
    private lateinit var context: Context
    private lateinit var tracker: Tracker
    private lateinit var trackerOffline: TrackerOffline
    private lateinit var mockClient: MobileIngestClientInterface

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        trackerOffline = mockk(relaxed = true)
        every { trackerOffline.getIdentify() } returns null
        mockClient = mockk<MobileIngestClientInterface>(relaxed = true)
        coEvery { mockClient.activity(any()) } returns Api.Response.getDefaultInstance()
        val mapper = ActivityMapper(context)
        tracker = Tracker(trackerOffline, mockClient, mapper, scope = testScope)
    }

    @After
    fun tearDown() {
        testScope.cancel()
    }

    @Test
    fun `identify should call client and save on success`() = testScope.runTest {
        val identify = Identify("user123")

        tracker.identify(identify, null)

        advanceUntilIdle()
        coVerify { mockClient.activity(any()) }
    }

    @Test
    fun `identify should save offline on exception`() = testScope.runTest {
        val identify = Identify("user123")
        coEvery { mockClient.activity(any()) } throws Exception("Network error")

        tracker.identify(identify, null)

        delay(500)
        verify { trackerOffline.identify(any(), false) }
    }

    @Test
    fun `identify should invoke callback on success`() = testScope.runTest {
        val identify = Identify("user123")
        var receivedStatus: Tracker.OperationStatus? = null
        val callback: (Tracker.OperationStatus?, Throwable?) -> Unit = { status, _ ->
            receivedStatus = status
        }

        tracker.identify(identify, callback)

        delay(500)
        assertThat(receivedStatus).isEqualTo(Tracker.OperationStatus.SENT)
    }

    @Test
    fun `event should call client`() = testScope.runTest {
        tracker.id = "user123"
        val event = Event("purchase")

        tracker.event(event)

        advanceUntilIdle()
        coVerify { mockClient.activity(any()) }
    }

    @Test
    fun `event should save offline on API error`() = testScope.runTest {
        tracker.id = "user123"
        val event = Event("purchase")
        coEvery { mockClient.activity(any()) } throws Exception("err")

        tracker.event(event)

        delay(500)
        verify { trackerOffline.event(any(), any()) }
    }

    @Test
    fun `registerToken should call client`() = testScope.runTest {
        tracker.id = "user123"

        tracker.registerToken("token123")

        advanceUntilIdle()
        coVerify { mockClient.activity(any()) }
    }

    @Test
    fun `unregisterToken should call client`() = testScope.runTest {
        tracker.id = "user123"

        tracker.unregisterToken("token123")

        advanceUntilIdle()
        coVerify { mockClient.activity(any()) }
    }

    @Test
    fun `logout should clear persisted identify`() = testScope.runTest {
        tracker.id = "user123"

        tracker.logout()

        advanceUntilIdle()
        verify { trackerOffline.deleteIdentify() }
        assertThat(tracker.idOrNull).isNull()
    }

    @Test
    fun `event after logout should go out anonymous, not as the previous user`() = testScope.runTest {
        val requests = anonymousDevice()
        tracker.id = "user123"
        tracker.logout()
        advanceUntilIdle()
        clearMocks(mockClient, trackerOffline, answers = false)

        tracker.event(Event("purchase"))

        advanceUntilIdle()
        assertThat(requests.single().userId).isEmpty()
        verify(exactly = 0) { trackerOffline.event(any(), any(), any()) }
    }

    @Test
    fun `track without identify should go out anonymous with the device id`() = testScope.runTest {
        val requests = anonymousDevice()

        tracker.event(Event("purchase"))

        advanceUntilIdle()
        val request = requests.single()
        assertThat(request.userId).isEmpty()
        assertThat(request.device.deviceId).isEqualTo("device-1")
        assertThat(request.activitiesList.single { it.hasTrack() }.track.event).isEqualTo("purchase")
        verify(exactly = 0) { trackerOffline.event(any(), any(), any()) }
    }

    @Test
    fun `registerToken without identify should go out anonymous`() = testScope.runTest {
        val requests = anonymousDevice()
        var error: Throwable? = null

        tracker.registerToken("token123") { _, e -> error = e }

        advanceUntilIdle()
        assertThat(error).isNull()
        val request = requests.single()
        assertThat(request.userId).isEmpty()
        assertThat(request.device.token).isEqualTo("token123")
        assertThat(request.activitiesList.single { it.hasTokenRegister() }.tokenRegister.token).isEqualTo("token123")
    }

    @Test
    fun `unregisterToken without identify should go out anonymous`() = testScope.runTest {
        val requests = anonymousDevice()
        var error: Throwable? = null

        tracker.unregisterToken("token123") { _, e -> error = e }

        advanceUntilIdle()
        assertThat(error).isNull()
        val request = requests.single()
        assertThat(request.userId).isEmpty()
        assertThat(request.activitiesList.single { it.hasTokenUnregister() }.tokenUnregister.token)
            .isEqualTo("token123")
    }

    @Test
    fun `track at startup should wait for the stored identify and go out identified`() {
        setAndroidId("device-1")
        val requests = Collections.synchronizedList(mutableListOf<Api.Request>())
        coEvery { mockClient.activity(capture(requests)) } returns Api.Response.getDefaultInstance()
        // Threads reais: o load fica preso no disco enquanto o track já está rodando.
        val loading = CountDownLatch(1)
        every { trackerOffline.getIdentify() } answers {
            loading.await(5, TimeUnit.SECONDS)
            storedIdentify()
        }
        val coldTracker = Tracker(trackerOffline, mockClient, ActivityMapper(context))
        try {
            coldTracker.event(Event("purchase"))
            Thread.sleep(300)
            assertThat(requests).isEmpty()

            loading.countDown()
            coVerify(timeout = 5000) { mockClient.activity(any()) }
            assertThat(requests.single().userId).isEqualTo("user123")
        } finally {
            loading.countDown()
            coldTracker.close()
        }
    }

    @Test
    fun `track and token right after identify should go out identified`() = testScope.runTest {
        val requests = anonymousDevice()

        tracker.identify(Identify("u1"), null)
        assertThat(tracker.idOrNull).isEqualTo("u1")
        tracker.event(Event("login"))
        tracker.registerToken("token123")

        advanceUntilIdle()
        assertThat(requests.single { r -> r.activitiesList.any { it.hasTrack() } }.userId).isEqualTo("u1")
        assertThat(requests.single { r -> r.activitiesList.any { it.hasTokenRegister() } }.userId).isEqualTo("u1")
        assertThat(requests.none { it.userId.isEmpty() }).isTrue()
    }

    @Test
    fun `logout during the identify request should not persist that user nor resend the token`() =
        testScope.runTest {
            val requests = anonymousDevice()
            AnonymousState(context).lastToken = "token123"

            tracker.identify(Identify("u1"), null)
            tracker.logout()

            advanceUntilIdle()
            verify(exactly = 0) { trackerOffline.identify(any(), any()) }
            assertThat(requests.none { r -> r.activitiesList.any { it.hasTokenRegister() } }).isTrue()
        }

    @Test
    fun `blank stored identify should be treated as absent and track goes out anonymous`() = testScope.runTest {
        val requests = anonymousDevice()
        every { trackerOffline.getIdentify() } returns storedIdentify().copy(id = "")
        val coldTracker = Tracker(trackerOffline, mockClient, ActivityMapper(context), scope = testScope)

        assertThat(coldTracker.awaitId()).isNull()
        coldTracker.event(Event("purchase"))

        advanceUntilIdle()
        val request = requests.single()
        assertThat(request.userId).isEmpty()
        assertThat(request.activitiesList.first().hasIdentify()).isTrue()
    }

    @Test
    fun `logout before the stored identify loads should not restore it`() = testScope.runTest {
        every { trackerOffline.getIdentify() } returns storedIdentify()
        val coldTracker = Tracker(trackerOffline, mockClient, ActivityMapper(context), scope = testScope)

        coldTracker.logout()

        assertThat(coldTracker.awaitId()).isNull()
    }

    @Test
    fun `concurrent anonymous calls should send the anonymous identify once`() = testScope.runTest {
        val requests = anonymousDevice()
        coEvery { mockClient.activity(capture(requests)) } coAnswers {
            delay(100)
            Api.Response.getDefaultInstance()
        }

        tracker.event(Event("purchase"))
        tracker.registerToken("token123")

        advanceUntilIdle()
        assertThat(requests).hasSize(2)
        assertThat(requests.count { r -> r.activitiesList.any { it.hasIdentify() } }).isEqualTo(1)
    }

    @Test
    fun `anonymous track that fails should be queued as anonymous`() = testScope.runTest {
        anonymousDevice()
        coEvery { mockClient.activity(any()) } throws Exception("err")

        tracker.event(Event("purchase"))

        advanceUntilIdle()
        verify { trackerOffline.event(any(), any(), true) }
    }

    @Test
    fun `anonymous identify should go with the first anonymous call only`() = testScope.runTest {
        val requests = anonymousDevice()

        tracker.event(Event("first"))
        advanceUntilIdle()
        tracker.event(Event("second"))
        advanceUntilIdle()

        val first = requests[0].activitiesList
        assertThat(first.first().hasIdentify()).isTrue()
        val customData = first.first().identify.customDataMap
        assertThat(customData.keys).containsExactly("device_model", "sdk_version")
        assertThat(customData["sdk_version"]?.single?.stringValue).isEqualTo(BuildConfig.DITO_SDK_VERSION)
        assertThat(first.last().hasTrack()).isTrue()
        assertThat(requests[1].activitiesList.none { it.hasIdentify() }).isTrue()
    }

    @Test
    fun `failed anonymous identify should be sent again on the next call`() = testScope.runTest {
        val requests = anonymousDevice()
        var calls = 0
        coEvery { mockClient.activity(capture(requests)) } answers {
            if (calls++ == 0) throw Exception("err")
            Api.Response.getDefaultInstance()
        }

        tracker.event(Event("first"))
        advanceUntilIdle()
        tracker.event(Event("second"))
        advanceUntilIdle()

        assertThat(requests).hasSize(2)
        assertThat(requests[1].activitiesList.first().hasIdentify()).isTrue()
    }

    @Test
    fun `anonymous identify should be sent again when the sdk version changes`() = testScope.runTest {
        val requests = anonymousDevice()
        AnonymousState(context).identifyMark = "device-1|0.0.0-antiga"

        tracker.event(Event("purchase"))

        advanceUntilIdle()
        assertThat(requests.single().activitiesList.first().hasIdentify()).isTrue()
    }

    @Test
    fun `anonymous identify should not be sent with a logged in user`() = testScope.runTest {
        val requests = anonymousDevice()
        tracker.id = "user123"

        tracker.event(Event("purchase"))

        advanceUntilIdle()
        assertThat(requests.single().activitiesList.none { it.hasIdentify() }).isTrue()
        assertThat(AnonymousState(context).identifyMark).isNull()
    }

    @Test
    fun `without android id, track is queued without owner and token fails as before`() = testScope.runTest {
        setAndroidId("")
        every { trackerOffline.getIdentify() } returns null
        var registerError: Throwable? = null
        var unregisterError: Throwable? = null

        tracker.event(Event("purchase"))
        tracker.registerToken("token123") { _, e -> registerError = e }
        tracker.unregisterToken("token123") { _, e -> unregisterError = e }

        advanceUntilIdle()
        coVerify(exactly = 0) { mockClient.activity(any()) }
        verify { trackerOffline.event(any(), any(), false) }
        assertThat(registerError).isInstanceOf(IllegalStateException::class.java)
        assertThat(unregisterError).isInstanceOf(IllegalStateException::class.java)
    }

    @Test
    fun `last registered token should be sent again after identify`() = testScope.runTest {
        val requests = anonymousDevice()
        tracker.registerToken("token123")
        advanceUntilIdle()

        tracker.identify(Identify("user123"), null)

        advanceUntilIdle()
        val resent = requests.last()
        assertThat(resent.userId).isEqualTo("user123")
        assertThat(resent.device.token).isEqualTo("token123")
        assertThat(resent.activitiesList.single().tokenRegister.token).isEqualTo("token123")
    }

    @Test
    fun `unregisterToken of the last token should stop the resend after identify`() = testScope.runTest {
        val requests = anonymousDevice()
        tracker.registerToken("token123")
        advanceUntilIdle()
        tracker.unregisterToken("token123")
        advanceUntilIdle()

        tracker.identify(Identify("user123"), null)

        advanceUntilIdle()
        assertThat(AnonymousState(context).lastToken).isNull()
        assertThat(requests.filter { it.userId == "user123" }.none { r -> r.activitiesList.any { it.hasTokenRegister() } })
            .isTrue()
    }

    @Test
    fun `awaitId should wait for the persisted identify to load`() = testScope.runTest {
        every { trackerOffline.getIdentify() } returns IdentifyOff(
            id = "user123",
            name = null,
            email = null,
            gender = null,
            birthday = null,
            location = null,
            customDataJson = null,
            send = true,
        )
        val coldTracker = Tracker(trackerOffline, mockClient, ActivityMapper(context), scope = testScope)
        // Leitura direta ainda não vê nada: é este instante que o flush no cold start pegava.
        assertThat(coldTracker.idOrNull).isNull()

        assertThat(coldTracker.awaitId()).isEqualTo("user123")
    }

    @Test
    fun `awaitId should not overwrite an identify set while loading`() = testScope.runTest {
        every { trackerOffline.getIdentify() } returns IdentifyOff(
            id = "stale-user",
            name = null,
            email = null,
            gender = null,
            birthday = null,
            location = null,
            customDataJson = null,
            send = true,
        )
        val coldTracker = Tracker(trackerOffline, mockClient, ActivityMapper(context), scope = testScope)
        coldTracker.id = "fresh-user"

        assertThat(coldTracker.awaitId()).isEqualTo("fresh-user")
    }

    @Test
    fun `notificationClick should not call client when reference is empty`() = testScope.runTest {
        tracker.id = "user123"

        tracker.notificationClick("", "", "")

        delay(500)
        coVerify(exactly = 0) { mockClient.activity(any()) }
    }

    @Test
    fun `notificationClick should call client with parameters`() = testScope.runTest {
        tracker.id = "user123"

        tracker.notificationClick("notif123", "ref123", "user123")

        advanceUntilIdle()
        coVerify { mockClient.activity(any()) }
    }

    @Test
    fun `notificationClick should save offline on API error`() = testScope.runTest {
        tracker.id = "user123"
        coEvery { mockClient.activity(any()) } throws Exception("err")

        tracker.notificationClick("notif123", "ref123", "user123")

        delay(500)
        verify { trackerOffline.notificationRead(any(), any(), any(), any()) }
    }

    @Test
    fun `notificationClick should persist action data offline on API error`() = testScope.runTest {
        tracker.id = "user123"
        coEvery { mockClient.activity(any()) } throws Exception("err")
        val actionData = mapOf("action_id" to "botao_1", "action_label" to "Botão 1")

        tracker.notificationClick("notif123", "ref123", "user123", actionData)

        delay(500)
        verify { trackerOffline.notificationRead(any(), "notif123", "user123", actionData) }
    }

    @Test
    fun `notificationReceived should queue delivery event on API error`() = testScope.runTest {
        coEvery { mockClient.activity(any()) } throws Exception("err")

        tracker.notificationReceived(notificationReadData())

        advanceUntilIdle()
        // Antes disto a exceção era engolida por um catch vazio: a entrega perdida não deixava
        // fila nem log, e era indistinguível de uma entrega bem-sucedida.
        verify { trackerOffline.event(any(), any()) }
    }

    @Test
    fun `notificationReceived should persist identify so the queue can be drained later`() = testScope.runTest {
        coEvery { mockClient.activity(any()) } throws Exception("err")
        every { trackerOffline.getIdentify() } returns null

        tracker.notificationReceived(notificationReadData())

        advanceUntilIdle()
        verify { trackerOffline.identify(any(), false) }
    }

    @Test
    fun `notificationReceived should not overwrite a richer stored identify`() = testScope.runTest {
        coEvery { mockClient.activity(any()) } throws Exception("err")
        every { trackerOffline.getIdentify() } returns IdentifyOff(
            id = "user123",
            name = "Igor",
            email = "igor@example.com",
            gender = null,
            birthday = null,
            location = null,
            customDataJson = null,
            send = true,
        )

        tracker.notificationReceived(notificationReadData())

        advanceUntilIdle()
        verify(exactly = 0) { trackerOffline.identify(any(), any()) }
        verify { trackerOffline.event(any(), any()) }
    }

    @Test
    fun `notificationReceived should not queue anything on success`() = testScope.runTest {
        tracker.notificationReceived(notificationReadData())

        advanceUntilIdle()
        coVerify { mockClient.activity(any()) }
        verify(exactly = 0) { trackerOffline.event(any(), any()) }
    }

    private fun setAndroidId(value: String) {
        Settings.Secure.putString(context.contentResolver, Settings.Secure.ANDROID_ID, value)
    }

    private fun anonymousDevice(): MutableList<Api.Request> {
        setAndroidId("device-1")
        every { trackerOffline.getIdentify() } returns null
        val requests = mutableListOf<Api.Request>()
        coEvery { mockClient.activity(capture(requests)) } returns Api.Response.getDefaultInstance()
        return requests
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

    private fun notificationReadData() = Dito.NotificationReadData(
        notificationId = "notif123",
        reference = "",
        logId = "log123",
        notificationName = "campanha",
        userId = "user123",
    )
}
