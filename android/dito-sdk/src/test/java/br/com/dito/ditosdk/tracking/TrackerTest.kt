package br.com.dito.ditosdk.tracking

import br.com.dito.ditosdk.Event
import br.com.dito.ditosdk.Identify
import br.com.dito.ditosdk.service.EventApi
import br.com.dito.ditosdk.service.LoginApi
import br.com.dito.ditosdk.service.NotificationApi
import br.com.dito.ditosdk.service.utils.EventRequest
import br.com.dito.ditosdk.service.utils.NotificationOpenRequest
import br.com.dito.ditosdk.service.utils.SigunpRequest
import com.google.common.truth.Truth.assertThat
import com.google.gson.JsonObject
import io.mockk.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.cancel
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import retrofit2.Response

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class TrackerTest {

    private val testScope = TestScope()
    private lateinit var tracker: Tracker
    private lateinit var trackerOffline: TrackerOffline
    private lateinit var mockLoginApi: LoginApi
    private lateinit var mockEventApi: EventApi
    private lateinit var mockNotificationApi: NotificationApi

    @Before
    fun setup() {
        trackerOffline = mockk(relaxed = true)
        tracker = Tracker("apiKey", "apiSecret", trackerOffline, testScope)
        mockLoginApi = mockk(relaxed = true)
        mockEventApi = mockk(relaxed = true)
        mockNotificationApi = mockk(relaxed = true)
    }

    @After
    fun tearDown() {
        testScope.cancel()
    }

    @Test
    fun `identify should call API and save reference on success`() = testScope.runTest {
        val identify = Identify("user123")
        val responseBody = JsonObject().apply {
            add("data", JsonObject().apply {
                addProperty("reference", "ref123")
            })
        }
        val response = Response.success(responseBody)
        coEvery { mockLoginApi.signup(any(), any(), any<SigunpRequest>()) } returns response

        tracker.identify(identify, mockLoginApi, null)

        advanceUntilIdle()
        coVerify { mockLoginApi.signup("portal", "user123", any<SigunpRequest>()) }
    }

    @Test
    fun `identify should save offline on API error`() = testScope.runTest {
        val identify = Identify("user123")
        val response = Response.error<JsonObject>(400, mockk(relaxed = true))
        coEvery { mockLoginApi.signup(any(), any(), any<SigunpRequest>()) } returns response

        tracker.identify(identify, mockLoginApi, null)

        delay(500)
        verify { trackerOffline.identify(any(), null, false) }
    }

    @Test
    fun `identify should save offline on exception`() = testScope.runTest {
        val identify = Identify("user123")
        coEvery { mockLoginApi.signup(any(), any(), any<SigunpRequest>()) } throws Exception("Network error")

        tracker.identify(identify, mockLoginApi, null)

        delay(500)
        verify { trackerOffline.identify(any(), null, false) }
    }

    @Test
    fun `identify should invoke callback on success`() = testScope.runTest {
        val identify = Identify("user123")
        var callbackInvoked = false
        val callback: () -> Unit = { callbackInvoked = true }
        val responseBody = JsonObject().apply {
            add("data", JsonObject().apply {
                addProperty("reference", "ref123")
            })
        }
        val response = Response.success(responseBody)
        coEvery { mockLoginApi.signup(any(), any(), any<SigunpRequest>()) } returns response

        tracker.identify(identify, mockLoginApi, callback)

        delay(500)
        assertThat(callbackInvoked).isTrue()
    }

    @Test
    fun `event should call API`() = testScope.runTest {
        tracker.id = "user123"
        val event = Event("purchase")
        val response = Response.success(JsonObject())
        coEvery { mockEventApi.track(any(), any<EventRequest>()) } returns response

        tracker.event(event, mockEventApi)

        advanceUntilIdle()
        coVerify { mockEventApi.track("user123", any<EventRequest>()) }
    }

    @Test
    fun `event should save offline on API error`() = testScope.runTest {
        tracker.id = "user123"
        val event = Event("purchase")
        val response = Response.error<JsonObject>(400, mockk(relaxed = true))
        coEvery { mockEventApi.track(any(), any<EventRequest>()) } returns response

        tracker.event(event, mockEventApi)

        delay(500)
        verify { trackerOffline.event(any()) }
    }

    @Test
    fun `event should save offline on exception`() = testScope.runTest {
        tracker.id = "user123"
        val event = Event("purchase")
        coEvery { mockEventApi.track(any(), any<EventRequest>()) } throws Exception("Network error")

        tracker.event(event, mockEventApi)

        delay(500)
        verify { trackerOffline.event(any()) }
    }

    @Test
    fun `registerToken should call API`() = testScope.runTest {
        tracker.id = "user123"
        val response = Response.success(JsonObject())
        coEvery { mockNotificationApi.add(any(), any()) } returns response

        tracker.registerToken("token123", mockNotificationApi)

        advanceUntilIdle()
        coVerify { mockNotificationApi.add("user123", any()) }
    }

    @Test
    fun `unregisterToken should call API`() = testScope.runTest {
        tracker.id = "user123"
        val response = Response.success(JsonObject())
        coEvery { mockNotificationApi.disable(any(), any()) } returns response

        tracker.unregisterToken("token123", mockNotificationApi)

        advanceUntilIdle()
        coVerify { mockNotificationApi.disable("user123", any()) }
    }

    @Test
    fun `notificationClick should not call API when reference is empty`() = testScope.runTest {
        tracker.id = "user123"

        tracker.notificationClick("", mockNotificationApi, "")

        delay(500)
        coVerify(exactly = 0) { mockNotificationApi.open(any(), any<NotificationOpenRequest>()) }
    }

    @Test
    fun `notificationClick should call API with correct parameters`() = testScope.runTest {
        tracker.id = "user123"
        val response = Response.success(JsonObject())
        coEvery { mockNotificationApi.open(any(), any<NotificationOpenRequest>()) } returns response

        tracker.notificationClick("notif123", mockNotificationApi, "ref123")

        advanceUntilIdle()
        coVerify { mockNotificationApi.open("notif123", any<NotificationOpenRequest>()) }
    }

    @Test
    fun `notificationClick should save offline on API error`() = testScope.runTest {
        tracker.id = "user123"
        val response = Response.error<JsonObject>(400, mockk(relaxed = true))
        coEvery { mockNotificationApi.open(any(), any<NotificationOpenRequest>()) } returns response

        tracker.notificationClick("notif123", mockNotificationApi, "ref123")

        delay(500)
        verify { trackerOffline.notificationRead(any()) }
    }
}
