package br.com.dito.ditosdk.integration

import androidx.test.ext.junit.runners.AndroidJUnit4
import br.com.dito.ditosdk.Dito
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
internal class OfflineQueueTest {
    private val interceptor = ProdHttpInterceptor()

    @get:Rule
    val server = RealServerRule(interceptor)

    @Before
    fun setUp() {
        interceptor.reset()
    }

    @Test
    fun tracksQueuedBeforeIdentifyAreFlushedAfterIdentify() {
        Dito.track("offline-event-1")
        Dito.track("offline-event-2")
        Dito.track("offline-event-3")
        Thread.sleep(1000)
        assert(interceptor.allCodes().isEmpty()) {
            "nenhum HTTP deve ser enviado antes do identify"
        }
        Dito.identify(server.userId, name = "Offline Test User")
        Thread.sleep(15000)
        Dito.track("post-identify-probe")
        Thread.sleep(5000)
        assert(interceptor.allCodes().any { it in 200..204 }) {
            "pelo menos 1 resposta HTTP 200/204 após identify confirma pipeline ativo"
        }
    }

    @Test
    fun notificationClickQueuedBeforeIdentifyIsFlushedAfterIdentify() {
        val userInfo = mapOf(
            "notification" to "test-notif-offline-${server.userId}",
            "reference" to "test-ref-offline-${server.userId}",
            "user_id" to server.userId,
            "notification_name" to "Offline Test Notification",
        )
        interceptor.reset()
        Dito.notificationClick(userInfo)
        Thread.sleep(1000)
        assert(interceptor.allCodes().isEmpty()) {
            "nenhum HTTP antes do identify"
        }
        Dito.identify(server.userId, name = "Offline Notif User")
        Thread.sleep(15000)
        Dito.track("post-identify-probe")
        Thread.sleep(5000)
        assert(interceptor.allCodes().any { it in 200..204 }) {
            "pelo menos 1 resposta HTTP 200/204 pós-identify confirma pipeline ativo"
        }
    }
}
