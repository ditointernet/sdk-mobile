package br.com.dito.ditosdk.tracking

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.EventOff
import br.com.dito.ditosdk.IdentifyOff
import br.com.dito.ditosdk.NotificationReadOff
import br.com.dito.ditosdk.service.ActivityMapper
import br.com.dito.ditosdk.service.MobileIngestClientInterface
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
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
