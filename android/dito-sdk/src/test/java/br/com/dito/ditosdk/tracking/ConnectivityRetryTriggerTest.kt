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
import io.mockk.verifyOrder
import kotlinx.coroutines.isActive
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
    private val validatedFlags = mutableListOf<Boolean>()

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        active = checkNotNull(connectivityManager.activeNetwork)
        shadowOf(connectivityManager).setNetworkCapabilities(active, capabilities(validated = true))
        trigger = ConnectivityRetryTrigger(context, {
            uploads++
            validatedFlags += it
        }, DEBOUNCE_MS, testScope)
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

    private fun captivePortal(): NetworkCapabilities =
        capabilities(validated = false).also {
            shadowOf(it).addCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL)
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
    fun `network validating within the grace period triggers once, after the debounce`() = testScope.runTest {
        trigger.start()

        callback().onLost(active)
        callback().onAvailable(network(77))
        callback().onCapabilitiesChanged(network(77), capabilities(validated = false))
        advanceTimeBy(ConnectivityRetryTrigger.UNVALIDATED_GRACE_MS - DEBOUNCE_MS - 1)
        assertThat(uploads).isEqualTo(0)

        validated(network(77))
        advanceTimeBy(DEBOUNCE_MS + 1)
        assertThat(uploads).isEqualTo(1)
        advanceUntilIdle()
        assertThat(validatedFlags).containsExactly(true)
    }

    @Test
    fun `network with internet that never validates triggers after the grace period`() = testScope.runTest {
        trigger.start()

        callback().onLost(active)
        callback().onCapabilitiesChanged(network(77), capabilities(validated = false))
        callback().onCapabilitiesChanged(network(77), capabilities(validated = false))
        advanceTimeBy(ConnectivityRetryTrigger.UNVALIDATED_GRACE_MS - 1)
        assertThat(uploads).isEqualTo(0)

        advanceTimeBy(2)
        assertThat(uploads).isEqualTo(1)
        advanceUntilIdle()
        // Sem validação o reenvio respeita a espera de falha: Wi-Fi com WAN morta que cai e volta.
        assertThat(validatedFlags).containsExactly(false)
    }

    @Test
    fun `captive portal network does not trigger`() = testScope.runTest {
        trigger.start()

        callback().onLost(active)
        callback().onCapabilitiesChanged(network(77), captivePortal())
        advanceUntilIdle()

        assertThat(uploads).isEqualTo(0)
    }

    @Test
    fun `isOnline should be false on a network that lost validation, and true when it validates again`() =
        testScope.runTest {
            trigger.start()
            assertThat(trigger.isOnline()).isTrue()

            callback().onCapabilitiesChanged(active, capabilities(validated = false))
            advanceUntilIdle()
            assertThat(trigger.isOnline()).isFalse()

            validated(active)
            assertThat(trigger.isOnline()).isTrue()
        }

    @Test
    fun `isOnline should accept a never validated network only after the grace period`() = testScope.runTest {
        trigger.start()
        callback().onLost(active)
        assertThat(trigger.isOnline()).isFalse()

        callback().onCapabilitiesChanged(network(77), capabilities(validated = false))
        advanceTimeBy(ConnectivityRetryTrigger.UNVALIDATED_GRACE_MS - 1)
        assertThat(trigger.isOnline()).isFalse()

        advanceTimeBy(2)
        assertThat(trigger.isOnline()).isTrue()
    }

    @Test
    fun `isOnline should accept an unvalidated network already active at start`() {
        shadowOf(connectivityManager).setNetworkCapabilities(active, capabilities(validated = false))

        trigger.start()

        assertThat(trigger.isOnline()).isTrue()
    }

    @Test
    fun `isOnline should reject a captive portal that became the default network`() = testScope.runTest {
        trigger.start()

        callback().onCapabilitiesChanged(network(77), captivePortal())
        advanceUntilIdle()

        assertThat(trigger.isOnline()).isFalse()
    }

    @Test
    fun `isOnline without observing the network should be true`() {
        assertThat(trigger.isOnline()).isTrue()
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
    fun `close cancels its own scope but not an injected one`() {
        val own = ConnectivityRetryTrigger(context, { uploads++ })
        own.close()
        assertThat(own.scope.isActive).isFalse()

        trigger.close()
        assertThat(testScope.isActive).isTrue()
    }

    @Test
    fun `initial delivery of the active network during registration does not trigger`() = testScope.runTest {
        val cm = mockk<ConnectivityManager>(relaxed = true)
        val ctx = mockk<Context>()
        every { ctx.getSystemService(any<String>()) } returns cm
        every { cm.activeNetwork } returns active
        every { cm.getNetworkCapabilities(active) } returns capabilities(validated = true)
        every { cm.registerDefaultNetworkCallback(any<ConnectivityManager.NetworkCallback>()) } answers {
            firstArg<ConnectivityManager.NetworkCallback>().onCapabilitiesChanged(active, capabilities(validated = true))
        }

        ConnectivityRetryTrigger(ctx, { uploads++ }, DEBOUNCE_MS, testScope).start()
        advanceUntilIdle()

        assertThat(uploads).isEqualTo(0)
    }

    @Test
    fun `start registers the callback before reading the current network`() {
        val cm = mockk<ConnectivityManager>(relaxed = true)
        val ctx = mockk<Context>()
        every { ctx.getSystemService(any<String>()) } returns cm

        ConnectivityRetryTrigger(ctx, { uploads++ }, DEBOUNCE_MS, testScope).start()

        verifyOrder {
            cm.registerDefaultNetworkCallback(any<ConnectivityManager.NetworkCallback>())
            cm.activeNetwork
        }
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
        trigger = ConnectivityRetryTrigger(context, retry::uploadEventsOnReconnect, DEBOUNCE_MS, testScope)
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
