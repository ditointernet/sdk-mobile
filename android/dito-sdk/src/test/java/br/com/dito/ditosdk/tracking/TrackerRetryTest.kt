package br.com.dito.ditosdk.tracking

import br.com.dito.ditosdk.EventOff
import br.com.dito.ditosdk.IdentifyOff
import br.com.dito.ditosdk.NotificationReadOff
import br.com.dito.ditosdk.service.EventApi
import br.com.dito.ditosdk.service.LoginApi
import br.com.dito.ditosdk.service.NotificationApi
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
class TrackerRetryTest {

    private val testScope = TestScope()
    private lateinit var tracker: Tracker
    private lateinit var trackerOffline: TrackerOffline
    private lateinit var trackerRetry: TrackerRetry
    private lateinit var mockLoginApi: LoginApi
    private lateinit var mockEventApi: EventApi
    private lateinit var mockNotificationApi: NotificationApi

    @Before
    fun setup() {
        trackerOffline = mockk(relaxed = true)
        tracker = Tracker("apiKey", "apiSecret", trackerOffline, testScope)
        tracker.id = "user123"
        mockLoginApi = mockk(relaxed = true)
        mockEventApi = mockk(relaxed = true)
        mockNotificationApi = mockk(relaxed = true)
        trackerRetry = TrackerRetry(
            tracker,
            trackerOffline,
            5,
            mockLoginApi,
            mockEventApi,
            mockNotificationApi,
            testScope
        )
    }

    @After
    fun tearDown() {
        testScope.cancel()
    }

    @Test
    fun `checkIdentify should update identify when API succeeds`() = testScope.runTest {
        val identifyOff = IdentifyOff("user123", "{}", "ref123", false)
        every { trackerOffline.getIdentify() } returns identifyOff

        val responseBody = JsonObject().apply {
            add("data", JsonObject().apply {
                addProperty("reference", "ref123")
            })
        }
        val response = Response.success(responseBody)
        coEvery { mockLoginApi.signup(any(), any(), any<JsonObject>()) } returns response

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify { trackerOffline.updateIdentify("user123", true) }
    }

    @Test
    fun `checkIdentify should not update when identify is already sent`() = testScope.runTest {
        val identifyOff = IdentifyOff("user123", "{}", "ref123", true)
        every { trackerOffline.getIdentify() } returns identifyOff

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify(exactly = 0) { trackerOffline.updateIdentify(any(), any()) }
    }

    @Test
    fun `checkEvent should delete event when retry limit reached`() = testScope.runTest {
        val eventOff = EventOff(1, "{}", 5)
        every { trackerOffline.getAllEvents() } returns listOf(eventOff)

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify { trackerOffline.delete(1, "Event") }
    }

    @Test
    fun `checkEvent should update retry on failure`() = testScope.runTest {
        val eventOff = EventOff(1, "{}", 0)
        every { trackerOffline.getAllEvents() } returns listOf(eventOff)

        val response = Response.error<JsonObject>(400, mockk(relaxed = true))
        coEvery { mockEventApi.track(any(), any<JsonObject>()) } returns response

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify { trackerOffline.update(1, 1, "Event") }
    }

    @Test
    fun `checkEvent should delete event on success`() = testScope.runTest {
        val eventOff = EventOff(1, "{}", 0)
        every { trackerOffline.getAllEvents() } returns listOf(eventOff)

        val response = Response.success(JsonObject())
        coEvery { mockEventApi.track(any(), any<JsonObject>()) } returns response

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify { trackerOffline.delete(1, "Event") }
    }

    @Test
    fun `checkNotificationRead should delete notification when retry limit reached`() = testScope.runTest {
        val notificationOff = NotificationReadOff(1, "{}", 5)
        every { trackerOffline.getAllNotificationRead() } returns listOf(notificationOff)

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify { trackerOffline.delete(1, "NotificationRead") }
    }

    @Test
    fun `checkNotificationRead should update retry on failure`() = testScope.runTest {
        val notificationOff = NotificationReadOff(1, "{}", 0)
        every { trackerOffline.getAllNotificationRead() } returns listOf(notificationOff)

        val response = Response.error<JsonObject>(400, mockk(relaxed = true))
        coEvery { mockNotificationApi.open(any(), any<JsonObject>()) } returns response

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify { trackerOffline.update(1, 1, "NotificationRead") }
    }

    @Test
    fun `checkNotificationRead should delete notification on success`() = testScope.runTest {
        val notificationOff = NotificationReadOff(1, "{}", 0)
        every { trackerOffline.getAllNotificationRead() } returns listOf(notificationOff)

        val response = Response.success(JsonObject())
        coEvery { mockNotificationApi.open(any(), any<JsonObject>()) } returns response

        trackerRetry.uploadEvents()

        advanceUntilIdle()
        verify { trackerOffline.delete(1, "NotificationRead") }
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
