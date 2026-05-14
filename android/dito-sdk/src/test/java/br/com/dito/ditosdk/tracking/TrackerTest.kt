package br.com.dito.ditosdk.tracking

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.Event
import br.com.dito.ditosdk.Identify
import br.com.dito.ditosdk.service.ActivityMapper
import br.com.dito.ditosdk.service.MobileIngestClientInterface
import com.google.common.truth.Truth.assertThat
import io.mockk.clearMocks
import io.mockk.coEvery
import io.mockk.coVerify
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
    fun `event after logout should not reuse previous identify`() = testScope.runTest {
        tracker.id = "user123"
        tracker.logout()
        advanceUntilIdle()
        clearMocks(mockClient, trackerOffline, answers = false)

        tracker.event(Event("purchase"))

        advanceUntilIdle()
        coVerify(exactly = 0) { mockClient.activity(any()) }
        verify { trackerOffline.event(any(), any()) }
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
        verify { trackerOffline.notificationRead(any(), any(), any()) }
    }
}
