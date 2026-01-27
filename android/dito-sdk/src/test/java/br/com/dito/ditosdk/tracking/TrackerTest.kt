package br.com.dito.ditosdk.tracking

import br.com.dito.ditosdk.Event
import br.com.dito.ditosdk.Identify
import br.com.dito.ditosdk.service.EventApi
import br.com.dito.ditosdk.service.LoginApi
import br.com.dito.ditosdk.service.NotificationApi
import br.com.dito.ditosdk.service.utils.SigunpRequest
import br.com.dito.ditosdk.service.utils.EventRequest
import br.com.dito.ditosdk.service.utils.NotificationOpenRequest
import com.google.common.truth.Truth.assertThat
import com.google.gson.JsonObject
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import io.mockk.slot
import io.mockk.ofType
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import retrofit2.Response

@RunWith(RobolectricTestRunner::class)
class TrackerTest {

    private lateinit var tracker: Tracker
    private lateinit var trackerOffline: TrackerOffline
    private lateinit var mockLoginApi: LoginApi
    private lateinit var mockEventApi: EventApi
    private lateinit var mockNotificationApi: NotificationApi

    @Before
    fun setup() {
        trackerOffline = mockk(relaxed = true)
        tracker = Tracker("apiKey", "apiSecret", trackerOffline)
        mockLoginApi = mockk(relaxed = true)
        mockEventApi = mockk(relaxed = true)
        mockNotificationApi = mockk(relaxed = true)
    }

    @Test
    fun `identify should call API and save reference on success`() = runBlocking {
        val identify = Identify("user123")
        val responseBody = JsonObject().apply {
            add("data", JsonObject().apply {
                addProperty("reference", "ref123")
            })
        }
        val response = Response.success(responseBody)
        coEvery { mockLoginApi.signup(any(), any(), ofType<SigunpRequest>()) } returns response

        tracker.identify(identify, mockLoginApi, null)

        delay(100)
        coVerify { mockLoginApi.signup("portal", "user123", ofType<SigunpRequest>()) }
    }

    @Test
    fun `identify should save offline on API error`() = runBlocking {
        val identify = Identify("user123")
        val response = Response.error<JsonObject>(400, mockk())
        coEvery { mockLoginApi.signup(any(), any(), ofType<SigunpRequest>()) } returns response

        tracker.identify(identify, mockLoginApi, null)

        delay(100)
        coVerify { trackerOffline.identify(any(), null, false) }
    }

    @Test
    fun `identify should save offline on exception`() = runBlocking {
        val identify = Identify("user123")
        coEvery { mockLoginApi.signup(any(), any(), ofType<SigunpRequest>()) } throws Exception("Network error")

        tracker.identify(identify, mockLoginApi, null)

        delay(100)
        coVerify { trackerOffline.identify(any(), null, false) }
    }

    @Test
    fun `identify should invoke callback on success`() = runBlocking {
        val identify = Identify("user123")
        var callbackInvoked = false
        val callback: () -> Unit = { callbackInvoked = true }
        val responseBody = JsonObject().apply {
            add("data", JsonObject().apply {
                addProperty("reference", "ref123")
            })
        }
        val response = Response.success(responseBody)
        coEvery { mockLoginApi.signup(any(), any(), ofType<SigunpRequest>()) } returns response

        tracker.identify(identify, mockLoginApi, callback)

        delay(100)
        assertThat(callbackInvoked).isTrue()
    }

    @Test
    fun `event should call API`() = runBlocking {
        tracker.id = "user123"
        val event = Event("purchase")
        val response = Response.success(JsonObject())
        coEvery { mockEventApi.track(any(), ofType<EventRequest>()) } returns response

        tracker.event(event, mockEventApi)

        delay(100)
        coVerify { mockEventApi.track("user123", ofType<EventRequest>()) }
    }

    @Test
    fun `event should save offline on API error`() = runBlocking {
        tracker.id = "user123"
        val event = Event("purchase")
        val response = Response.error<JsonObject>(400, mockk())
        coEvery { mockEventApi.track(any(), ofType<EventRequest>()) } returns response

        tracker.event(event, mockEventApi)

        delay(100)
        coVerify { trackerOffline.event(any()) }
    }

    @Test
    fun `event should save offline on exception`() = runBlocking {
        tracker.id = "user123"
        val event = Event("purchase")
        coEvery { mockEventApi.track(any(), ofType<EventRequest>()) } throws Exception("Network error")

        tracker.event(event, mockEventApi)

        delay(100)
        coVerify { trackerOffline.event(any()) }
    }

    @Test
    fun `registerToken should call API`() = runBlocking {
        tracker.id = "user123"
        val response = Response.success(JsonObject())
        coEvery { mockNotificationApi.add(any(), any()) } returns response

        tracker.registerToken("token123", mockNotificationApi)

        delay(100)
        coVerify { mockNotificationApi.add("user123", any()) }
    }

    @Test
    fun `unregisterToken should call API`() = runBlocking {
        tracker.id = "user123"
        val response = Response.success(JsonObject())
        coEvery { mockNotificationApi.disable(any(), any()) } returns response

        tracker.unregisterToken("token123", mockNotificationApi)

        delay(100)
        coVerify { mockNotificationApi.disable("user123", any()) }
    }

    @Test
    fun `notificationRead should not call API when reference is empty`() = runBlocking {
        tracker.id = "user123"

        tracker.notificationRead("", mockNotificationApi, "")

        delay(100)
        coVerify(exactly = 0) { mockNotificationApi.open(any(), any()) }
    }

    @Test
    fun `notificationRead should call API with correct parameters`() = runBlocking {
        tracker.id = "user123"
        val response = Response.success(JsonObject())
        coEvery { mockNotificationApi.open(any(), ofType<NotificationOpenRequest>()) } returns response

        tracker.notificationRead("notif123", mockNotificationApi, "ref123")

        delay(100)
        coVerify { mockNotificationApi.open("notif123", ofType<NotificationOpenRequest>()) }
    }

    @Test
    fun `notificationRead should save offline on API error`() = runBlocking {
        tracker.id = "user123"
        val response = Response.error<JsonObject>(400, mockk())
        coEvery { mockNotificationApi.open(any(), ofType<NotificationOpenRequest>()) } returns response

        tracker.notificationRead("notif123", mockNotificationApi, "ref123")

        delay(100)
        coVerify { trackerOffline.notificationRead(any()) }
    }
}
