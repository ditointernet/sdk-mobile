package br.com.dito.ditosdk.integration

import androidx.test.ext.junit.runners.AndroidJUnit4
import br.com.dito.ditosdk.Dito
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
internal class NotificationTest {
    private val interceptor = ProdHttpInterceptor()

    @get:Rule
    val server = RealServerRule(interceptor)

    private lateinit var userInfo: Map<String, String>

    @Before
    fun setUp() {
        interceptor.reset()
        userInfo = mapOf(
            "notification" to "test-notif-${server.userId}",
            "reference" to "test-ref-${server.userId}",
            "user_id" to server.userId,
            "notification_name" to "Integration Test Notification",
        )
    }

    @Test
    fun notificationClickReturns200() {
        Dito.identify(server.userId, name = "Notif User Android")
        Thread.sleep(5000)
        interceptor.reset()
        Dito.notificationClick(userInfo)
        Thread.sleep(5000)
        assert(interceptor.lastCode() in 200..204) {
            "notificationClick deve retornar 200 ou 204, obtido: ${interceptor.lastCode()}"
        }
    }

    @Test
    fun notificationReadReturns200() {
        Dito.identify(server.userId, name = "Notif User Android")
        Thread.sleep(5000)
        interceptor.reset()
        Dito.notificationRead(userInfo)
        Thread.sleep(5000)
        assert(interceptor.lastCode() in 200..204) {
            "notificationRead deve retornar 200 ou 204, obtido: ${interceptor.lastCode()}"
        }
    }
}
