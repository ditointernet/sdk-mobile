package br.com.dito.ditosdk.tracking

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.provider.Settings
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.EventOff
import br.com.dito.ditosdk.service.ActivityMapper
import br.com.dito.ditosdk.service.MobileIngestClientInterface
import com.google.common.truth.Truth.assertThat
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import mobileingest.v1.Api
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowNetwork
import org.robolectric.shadows.ShadowNetworkCapabilities
import java.io.IOException

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class ConnectivityRetryTriggerTest {

    private val testScope = TestScope()
    private lateinit var context: Context
    private lateinit var connectivityManager: ConnectivityManager
    private lateinit var active: Network
    private lateinit var trigger: ConnectivityRetryTrigger
    private var uploads = 0

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        active = checkNotNull(connectivityManager.activeNetwork)
        shadowOf(connectivityManager).setNetworkCapabilities(active, capabilities(validated = true))
        trigger = ConnectivityRetryTrigger(context, { uploads++ }, DEBOUNCE_MS, testScope)
    }

    @After
    fun tearDown() {
        trigger.close()
    }

    private fun callback(): ConnectivityManager.NetworkCallback =
        shadowOf(connectivityManager).networkCallbacks.single()

    private fun network(id: Int): Network = ShadowNetwork.newInstance(id)

    private fun capabilities(validated: Boolean): NetworkCapabilities =
        ShadowNetworkCapabilities.newInstance().also {
            shadowOf(it).addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            if (validated) shadowOf(it).addCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        }

    private fun validated(network: Network) = callback().onCapabilitiesChanged(network, capabilities(validated = true))

    @Test
    fun `start registers exactly one callback and close removes it`() {
        trigger.start()
        assertThat(shadowOf(connectivityManager).networkCallbacks).hasSize(1)

        trigger.close()
        assertThat(shadowOf(connectivityManager).networkCallbacks).isEmpty()
    }

    @Test
    fun `redelivery of the already active network does not trigger`() = testScope.runTest {
        trigger.start()

        callback().onAvailable(active)
        validated(active)
        advanceUntilIdle()

        assertThat(uploads).isEqualTo(0)
    }

    @Test
    fun `network switch without onLost triggers once after the debounce`() = testScope.runTest {
        trigger.start()

        callback().onAvailable(network(77))
        validated(network(77))
        validated(network(77))
        advanceTimeBy(DEBOUNCE_MS - 1)
        assertThat(uploads).isEqualTo(0)

        advanceTimeBy(2)
        assertThat(uploads).isEqualTo(1)
        advanceUntilIdle()
        assertThat(uploads).isEqualTo(1)
    }

    @Test
    fun `network without validation does not trigger until validated`() = testScope.runTest {
        trigger.start()

        callback().onLost(active)
        callback().onAvailable(network(77))
        callback().onCapabilitiesChanged(network(77), capabilities(validated = false))
        advanceUntilIdle()
        assertThat(uploads).isEqualTo(0)

        validated(network(77))
        advanceUntilIdle()
        assertThat(uploads).isEqualTo(1)
    }

    @Test
    fun `same network losing and regaining validation triggers once`() = testScope.runTest {
        trigger.start()

        callback().onCapabilitiesChanged(active, capabilities(validated = false))
        advanceUntilIdle()
        assertThat(uploads).isEqualTo(0)

        validated(active)
        advanceUntilIdle()
        assertThat(uploads).isEqualTo(1)
    }

    @Test
    fun `cold start without network triggers when a validated network arrives`() = testScope.runTest {
        shadowOf(connectivityManager).setDefaultNetworkActive(false)
        assertThat(connectivityManager.activeNetwork).isNull()
        trigger.start()

        validated(network(77))
        advanceTimeBy(DEBOUNCE_MS - 1)
        assertThat(uploads).isEqualTo(0)

        advanceUntilIdle()
        assertThat(uploads).isEqualTo(1)
    }

    @Test
    fun `flapping network within the debounce triggers once`() = testScope.runTest {
        trigger.start()

        callback().onLost(active)
        validated(network(77))
        advanceTimeBy(DEBOUNCE_MS / 2)
        callback().onLost(network(77))
        validated(network(78))
        advanceTimeBy(DEBOUNCE_MS / 2)
        callback().onLost(network(78))
        validated(network(79))
        advanceUntilIdle()

        assertThat(uploads).isEqualTo(1)
    }

    @Test
    fun `losing the network cancels the scheduled upload`() = testScope.runTest {
        trigger.start()

        validated(network(77))
        callback().onLost(network(77))
        advanceUntilIdle()

        assertThat(uploads).isEqualTo(0)
    }

    @Test
    fun `close cancels the scheduled upload`() = testScope.runTest {
        trigger.start()
        val registered = callback()

        registered.onLost(active)
        registered.onCapabilitiesChanged(network(77), capabilities(validated = true))
        trigger.close()
        advanceUntilIdle()

        assertThat(uploads).isEqualTo(0)
    }

    @Test
    fun `registration failures do not throw`() {
        val throwing = mockk<Context>()
        every { throwing.getSystemService(any<String>()) } throws SecurityException("sem permissão")
        ConnectivityRetryTrigger(throwing, { uploads++ }).apply { start(); close() }

        val missing = mockk<Context>()
        every { missing.getSystemService(any<String>()) } returns null
        ConnectivityRetryTrigger(missing, { uploads++ }).apply { start(); close() }

        val cm = mockk<ConnectivityManager>(relaxed = true)
        val denied = SecurityException("sem permissão")
        every { cm.registerDefaultNetworkCallback(any<ConnectivityManager.NetworkCallback>()) } throws denied
        val refusing = mockk<Context>()
        every { refusing.getSystemService(any<String>()) } returns cm
        ConnectivityRetryTrigger(refusing, { uploads++ }).apply { start(); close() }

        assertThat(uploads).isEqualTo(0)
    }

    @Test
    fun `anonymous event that failed offline is resent when the network comes back`() = testScope.runTest {
        Settings.Secure.putString(context.contentResolver, Settings.Secure.ANDROID_ID, "device-1")
        var queue = listOf(EventOff(1, "a1", "x", null, null, "t", 0, anonymous = true))
        val trackerOffline = mockk<TrackerOffline>(relaxed = true)
        every { trackerOffline.getIdentify() } returns null
        every { trackerOffline.getAllNotificationRead() } returns null
        every { trackerOffline.getAllEvents() } answers { queue }
        every { trackerOffline.update(1, any(), "Event") } answers { queue = listOf(queue.single().copy(retry = secondArg<Int>())) }
        every { trackerOffline.delete(1, "Event") } answers { queue = emptyList() }
        val client = mockk<MobileIngestClientInterface>()
        val requests = mutableListOf<Api.Request>()
        var calls = 0
        coEvery { client.activity(capture(requests)) } answers {
            if (calls++ == 0) throw IOException("sem rede")
            Api.Response.getDefaultInstance()
        }
        val mapper = ActivityMapper(context)
        val tracker = Tracker(trackerOffline, client, mapper, AnonymousState(context), scope = testScope)
        val retry = TrackerRetry(tracker, trackerOffline, client, mapper, 5, testScope)
        trigger = ConnectivityRetryTrigger(context, retry::uploadEvents, DEBOUNCE_MS, testScope)
        trigger.start()

        retry.uploadEvents()
        advanceUntilIdle()
        verify { trackerOffline.update(1, 1, "Event") }
        verify(exactly = 0) { trackerOffline.delete(1, "Event") }

        callback().onLost(active)
        validated(network(77))
        advanceUntilIdle()

        verify { trackerOffline.delete(1, "Event") }
        assertThat(requests).hasSize(2)
        assertThat(requests.last().userId).isEmpty()
        assertThat(requests.last().activitiesList.last().id).isEqualTo("a1")
        assertThat(queue).isEmpty()
    }

    private companion object {
        const val DEBOUNCE_MS = 2_000L
    }
}
