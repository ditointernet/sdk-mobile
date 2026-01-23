package br.com.dito.ditosdk.tracking

import br.com.dito.ditosdk.EventOff
import br.com.dito.ditosdk.IdentifyOff
import br.com.dito.ditosdk.NotificationReadOff
import br.com.dito.ditosdk.service.EventApi
import br.com.dito.ditosdk.service.LoginApi
import br.com.dito.ditosdk.service.NotificationApi
import com.google.common.truth.Truth.assertThat
import com.google.gson.JsonObject
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import retrofit2.Response

@RunWith(RobolectricTestRunner::class)
class TrackerRetryTest {

    private lateinit var tracker: Tracker
    private lateinit var trackerOffline: TrackerOffline
    private lateinit var trackerRetry: TrackerRetry
    private lateinit var mockLoginApi: LoginApi
    private lateinit var mockEventApi: EventApi
    private lateinit var mockNotificationApi: NotificationApi

    @Before
    fun setup() {
        trackerOffline = mockk(relaxed = true)
        tracker = Tracker("apiKey", "apiSecret", trackerOffline)
        tracker.id = "user123"
        trackerRetry = TrackerRetry(tracker, trackerOffline, 5)
        mockLoginApi = mockk(relaxed = true)
        mockEventApi = mockk(relaxed = true)
        mockNotificationApi = mockk(relaxed = true)
    }

    @Test
    fun `checkIdentify should update identify when API succeeds`() = runBlocking {
        val identifyOff = IdentifyOff("user123", "{}", "ref123", false)
        every { trackerOffline.getIdentify() } returns identifyOff

        val responseBody = JsonObject().apply {
            add("data", JsonObject().apply {
                addProperty("reference", "ref123")
            })
        }
        val response = Response.success(responseBody)
        coEvery { mockLoginApi.signup(any(), any(), any()) } returns response

        trackerRetry.uploadEvents()

        delay(200)
        coVerify { trackerOffline.updateIdentify("user123", true) }
    }

    @Test
    fun `checkIdentify should not update when identify is already sent`() = runBlocking {
        val identifyOff = IdentifyOff("user123", "{}", "ref123", true)
        every { trackerOffline.getIdentify() } returns identifyOff

        trackerRetry.uploadEvents()

        delay(200)
        coVerify(exactly = 0) { trackerOffline.updateIdentify(any(), any()) }
    }

    @Test
    fun `checkEvent should delete event when retry limit reached`() = runBlocking {
        val eventOff = EventOff(1, "{}", 5)
        every { trackerOffline.getAllEvents() } returns listOf(eventOff)

        trackerRetry.uploadEvents()

        delay(200)
        coVerify { trackerOffline.delete(1, "Event") }
    }

    @Test
    fun `checkEvent should update retry on failure`() = runBlocking {
        val eventOff = EventOff(1, "{}", 0)
        every { trackerOffline.getAllEvents() } returns listOf(eventOff)

        val response = Response.error<JsonObject>(400, mockk())
        coEvery { mockEventApi.track(any(), any()) } returns response

        trackerRetry.uploadEvents()

        delay(200)
        coVerify { trackerOffline.update(1, 1, "Event") }
    }

    @Test
    fun `checkEvent should delete event on success`() = runBlocking {
        val eventOff = EventOff(1, "{}", 0)
        every { trackerOffline.getAllEvents() } returns listOf(eventOff)

        val response = Response.success(JsonObject())
        coEvery { mockEventApi.track(any(), any()) } returns response

        trackerRetry.uploadEvents()

        delay(200)
        coVerify { trackerOffline.delete(1, "Event") }
    }

    @Test
    fun `checkNotificationRead should delete notification when retry limit reached`() = runBlocking {
        val notificationOff = NotificationReadOff(1, "{}", 5)
        every { trackerOffline.getAllNotificationRead() } returns listOf(notificationOff)

        trackerRetry.uploadEvents()

        delay(200)
        coVerify { trackerOffline.delete(1, "NotificationRead") }
    }

    @Test
    fun `checkNotificationRead should update retry on failure`() = runBlocking {
        val notificationOff = NotificationReadOff(1, "{}", 0)
        every { trackerOffline.getAllNotificationRead() } returns listOf(notificationOff)

        val response = Response.error<JsonObject>(400, mockk())
        coEvery { mockNotificationApi.open(any(), any()) } returns response

        trackerRetry.uploadEvents()

        delay(200)
        coVerify { trackerOffline.update(1, 1, "NotificationRead") }
    }

    @Test
    fun `checkNotificationRead should delete notification on success`() = runBlocking {
        val notificationOff = NotificationReadOff(1, "{}", 0)
        every { trackerOffline.getAllNotificationRead() } returns listOf(notificationOff)

        val response = Response.success(JsonObject())
        coEvery { mockNotificationApi.open(any(), any()) } returns response

        trackerRetry.uploadEvents()

        delay(200)
        coVerify { trackerOffline.delete(1, "NotificationRead") }
    }

    @Test
    fun `uploadEvents should check all types`() = runBlocking {
        every { trackerOffline.getIdentify() } returns null
        every { trackerOffline.getAllEvents() } returns null
        every { trackerOffline.getAllNotificationRead() } returns null

        trackerRetry.uploadEvents()

        delay(200)
        coVerify { trackerOffline.getIdentify() }
        coVerify { trackerOffline.getAllEvents() }
        coVerify { trackerOffline.getAllNotificationRead() }
    }
}
