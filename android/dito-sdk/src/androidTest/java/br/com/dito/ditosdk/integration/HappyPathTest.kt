package br.com.dito.ditosdk.integration

import androidx.test.ext.junit.runners.AndroidJUnit4
import br.com.dito.ditosdk.Dito
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
internal class HappyPathTest {
    private val interceptor = ProdHttpInterceptor()

    @get:Rule
    val server = RealServerRule(interceptor)

    @Before
    fun setUp() {
        interceptor.reset()
    }

    @Test
    fun identifyReturns200() {
        Dito.identify(server.userId, name = "Test User Android")
        Thread.sleep(5000)
        assert(interceptor.lastCode() in 200..204) {
            "identify deve retornar 200 ou 204, obtido: ${interceptor.lastCode()}"
        }
    }

    @Test
    fun trackReturns200() {
        Dito.identify(server.userId, name = "Test User Android")
        Thread.sleep(5000)
        interceptor.reset()
        Dito.track("test-event")
        Thread.sleep(5000)
        assert(interceptor.lastCode() in 200..204) {
            "track deve retornar 200 ou 204, obtido: ${interceptor.lastCode()}"
        }
    }

    @Test
    fun registerDeviceReturns200() {
        Dito.identify(server.userId, name = "Test User Android")
        Thread.sleep(5000)
        interceptor.reset()
        Dito.registerDevice("fake-fcm-${server.userId}")
        Thread.sleep(5000)
        assert(interceptor.lastCode() in 200..204) {
            "registerDevice deve retornar 200 ou 204, obtido: ${interceptor.lastCode()}"
        }
    }

    @Test
    fun unregisterDeviceReturns200() {
        Dito.identify(server.userId, name = "Test User Android")
        Thread.sleep(5000)
        Dito.registerDevice("fake-fcm-${server.userId}")
        Thread.sleep(5000)
        interceptor.reset()
        Dito.unregisterDevice("fake-fcm-${server.userId}")
        Thread.sleep(5000)
        assert(interceptor.lastCode() in 200..204) {
            "unregisterDevice deve retornar 200 ou 204, obtido: ${interceptor.lastCode()}"
        }
    }
}
