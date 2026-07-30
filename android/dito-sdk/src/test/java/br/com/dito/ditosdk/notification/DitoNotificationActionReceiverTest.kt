package br.com.dito.ditosdk.notification

import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.Dito
import br.com.dito.ditosdk.NotificationResult
import io.mockk.every
import io.mockk.mockkObject
import io.mockk.unmockkObject
import io.mockk.verify
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * O registro do clique em botão não pode depender de `reference`.
 *
 * O campo está em retirada dos payloads da Dito, e enquanto ele era obrigatório aqui o
 * receiver descartava o clique em silêncio — reproduzido no emulador com a linha
 * `❌ Cannot call notificationClick: reference=, notificationId=case5-notification`.
 */
@RunWith(RobolectricTestRunner::class)
class DitoNotificationActionReceiverTest {

    private lateinit var context: Context
    private val receiver = DitoNotificationActionReceiver()

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        mockkObject(Dito)
        every { Dito.isInitialized() } returns true
        every { Dito.notificationClick(any(), any()) } returns
            NotificationResult(notificationId = "", reference = "", deepLink = "")
    }

    @After
    fun tearDown() {
        unmockkObject(Dito)
    }

    private fun clickIntent(notificationId: String, reference: String?): Intent =
        Intent(DitoNotificationActionReceiver.ACTION_NOTIFICATION_ACTION_CLICK).apply {
            putExtra(DitoNotificationActionReceiver.EXTRA_ACTION_ID, "comprar_agora")
            putExtra(DitoNotificationActionReceiver.EXTRA_ACTION_LABEL, "Comprar agora")
            putExtra(DitoNotificationActionReceiver.EXTRA_NOTIFICATION, notificationId)
            putExtra(DitoNotificationActionReceiver.EXTRA_LINK, "app://dito/comprar")
            putExtra(DitoNotificationActionReceiver.EXTRA_USER_ID, "user-1")
            reference?.let { putExtra(DitoNotificationActionReceiver.EXTRA_REFERENCE, it) }
        }

    @Test
    fun `registra o clique quando o payload nao traz reference`() {
        receiver.onReceive(context, clickIntent("case5-notification", reference = null))

        verify(exactly = 1) { Dito.notificationClick(any(), any()) }
    }

    @Test
    fun `registra o clique quando reference vem vazia`() {
        receiver.onReceive(context, clickIntent("case5-notification", reference = ""))

        verify(exactly = 1) { Dito.notificationClick(any(), any()) }
    }

    @Test
    fun `ainda ignora o clique sem notification id, que e o unico campo indispensavel`() {
        receiver.onReceive(context, clickIntent("", reference = "ref-1"))

        verify(exactly = 0) { Dito.notificationClick(any(), any()) }
    }

    @Test
    fun `leva o action id tocado no mapa do clique`() {
        receiver.onReceive(context, clickIntent("case3-notification", reference = null))

        verify {
            Dito.notificationClick(
                match { it[DitoNotificationActionReceiver.EXTRA_ACTION_ID] == "comprar_agora" },
                any(),
            )
        }
    }
}
