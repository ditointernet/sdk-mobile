package br.com.dito.ditosdk.notification

import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.Dito
import io.mockk.every
import io.mockk.mockkObject
import io.mockk.unmockkObject
import io.mockk.verify
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * A tela que recebe o toque na notificação tem duas obrigações que já foram quebradas:
 * abrir o app mesmo quando o SDK não consegue se inicializar, e registrar o clique de
 * campanhas que não mandam `reference`.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "pt-rBR")
class NotificationOpenedActivityTest {

    private lateinit var context: Context

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        mockkObject(Dito)
        every { Dito.isInitialized() } returns false
        every { Dito.getHibridMode() } returns "OFF"
        every { Dito.options } returns null
        every { Dito.notificationClickListener } returns null
        every { Dito.notificationClick(any(), any()) } returns
            NotificationResultFixture.empty()
    }

    @After
    fun tearDown() {
        unmockkObject(Dito)
    }

    private fun tapIntent(
        notificationId: String,
        reference: String?,
        actionId: String? = null,
    ): Intent = Intent(context, NotificationOpenedActivity::class.java).apply {
        putExtra(Dito.DITO_NOTIFICATION_ID, notificationId)
        putExtra(Dito.DITO_DEEP_LINK, "app://dito/case")
        reference?.let { putExtra(Dito.DITO_NOTIFICATION_REFERENCE, it) }
        actionId?.let {
            putExtra(DitoNotificationActionReceiver.EXTRA_ACTION_ID, it)
            putExtra(DitoNotificationActionReceiver.EXTRA_ACTION_LABEL, "Comprar agora")
        }
    }

    @Test
    fun `nao derruba o app quando o SDK nao consegue inicializar no clique`() {
        // É o cenário de Flutter e React Native: as credenciais vêm por código, não há
        // `br.com.dito.API_KEY` no manifest, e `Dito.init` lança. Antes deste catch, todo
        // toque em notificação depois da morte do processo terminava em crash.
        every { Dito.init(any<Context>(), null) } throws
            RuntimeException("É preciso configurar API_KEY no AndroidManifest.")

        val controller = Robolectric.buildActivity(
            NotificationOpenedActivity::class.java,
            tapIntent("case1-notification", reference = "ref-1"),
        ).create()

        verify { Dito.notificationClick(any(), any()) }
        controller.destroy()
    }

    @Test
    fun `registra o clique no corpo sem reference no payload`() {
        every { Dito.init(any<Context>(), null) } returns Unit

        val controller = Robolectric.buildActivity(
            NotificationOpenedActivity::class.java,
            tapIntent("case5-notification", reference = null),
        ).create()

        verify(exactly = 1) { Dito.notificationClick(any(), any()) }
        controller.destroy()
    }

    @Test
    fun `ignora o clique sem notification id`() {
        every { Dito.init(any<Context>(), null) } returns Unit

        val controller = Robolectric.buildActivity(
            NotificationOpenedActivity::class.java,
            tapIntent("", reference = "ref-1"),
        ).create()

        verify(exactly = 0) { Dito.notificationClick(any(), any()) }
        controller.destroy()
    }
}

private object NotificationResultFixture {
    fun empty() = br.com.dito.ditosdk.NotificationResult(
        notificationId = "",
        reference = "",
        deepLink = "",
    )
}
