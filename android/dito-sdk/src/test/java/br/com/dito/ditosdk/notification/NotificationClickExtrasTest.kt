package br.com.dito.ditosdk.notification

import android.content.Intent
import android.os.Build
import br.com.dito.ditosdk.Dito
import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [Build.VERSION_CODES.O])
class NotificationClickExtrasTest {

    private fun bodyClick() = NotificationClickExtras(
        notificationId = "n1",
        reference = "ref1",
        deepLink = "myapp://home",
        userId = "u1",
        actionId = "",
        actionLabel = "",
        customDataJson = """{"sku":"123"}""",
    )

    private fun actionClick() = bodyClick().copy(
        deepLink = "https://loja.example.com/carrinho",
        actionId = "buy",
        actionLabel = "Comprar",
    )

    // (a) toque no corpo não é toque em botão; toque em botão é.
    @Test
    fun `isActionClick reflete a presenca de actionId`() {
        assertThat(bodyClick().isActionClick).isFalse()
        assertThat(actionClick().isActionClick).isTrue()
    }

    // (b) o Intent que abre o app carrega o toque inteiro, não só o deeplink.
    @Test
    fun `writeTo grava o payload completo do toque`() {
        val target = Intent()

        actionClick().writeTo(target)

        assertThat(target.getStringExtra(Dito.DITO_NOTIFICATION_ID)).isEqualTo("n1")
        assertThat(target.getStringExtra(Dito.DITO_NOTIFICATION_REFERENCE)).isEqualTo("ref1")
        assertThat(target.getStringExtra(Dito.DITO_DEEP_LINK))
            .isEqualTo("https://loja.example.com/carrinho")
        assertThat(target.getStringExtra(Dito.DITO_USER_ID)).isEqualTo("u1")
        assertThat(target.getStringExtra(Dito.DITO_ACTION_ID)).isEqualTo("buy")
        assertThat(target.getStringExtra(Dito.DITO_ACTION_LABEL)).isEqualTo("Comprar")
        assertThat(target.getStringExtra(Dito.DITO_CUSTOM_DATA))
            .isEqualTo("""{"sku":"123"}""")
    }

    // (c) regressão: o contentIntent é um objeto só, reaproveitado. Um toque no corpo depois de um
    // toque em botão não pode herdar o actionId do anterior.
    @Test
    fun `writeTo limpa o actionId de um toque anterior no mesmo Intent`() {
        val reused = Intent()
        actionClick().writeTo(reused)

        bodyClick().writeTo(reused)

        assertThat(reused.getStringExtra(Dito.DITO_ACTION_ID)).isEmpty()
        assertThat(reused.getStringExtra(Dito.DITO_ACTION_LABEL)).isEmpty()
        assertThat(reused.getStringExtra(Dito.DITO_DEEP_LINK)).isEqualTo("myapp://home")
    }

    // (d) o que writeTo grava, from lê de volta.
    @Test
    fun `from le de volta o que writeTo gravou`() {
        val click = actionClick()

        assertThat(NotificationClickExtras.from(click.writeTo(Intent()))).isEqualTo(click)
    }

    // (e) o PendingIntent do corpo usa as constantes do SDK.
    @Test
    fun `from le as constantes do SDK`() {
        val intent = Intent().apply {
            putExtra(Dito.DITO_NOTIFICATION_ID, "n2")
            putExtra(Dito.DITO_NOTIFICATION_REFERENCE, "ref2")
            putExtra(Dito.DITO_DEEP_LINK, "myapp://p/2")
        }

        val click = NotificationClickExtras.from(intent)

        assertThat(click.notificationId).isEqualTo("n2")
        assertThat(click.reference).isEqualTo("ref2")
        assertThat(click.deepLink).isEqualTo("myapp://p/2")
        assertThat(click.isActionClick).isFalse()
    }

    // (f) e cai para as chaves cruas do FCM quando o PendingIntent veio do payload.
    @Test
    fun `from cai para as chaves cruas do payload FCM`() {
        val intent = Intent().apply {
            putExtra("notification", "n3")
            putExtra("reference", "ref3")
            putExtra("link", "myapp://p/3")
            putExtra("user_id", "u3")
        }

        val click = NotificationClickExtras.from(intent)

        assertThat(click.notificationId).isEqualTo("n3")
        assertThat(click.reference).isEqualTo("ref3")
        assertThat(click.deepLink).isEqualTo("myapp://p/3")
        assertThat(click.userId).isEqualTo("u3")
    }

    // (g) Intent nulo não explode nem inventa dado.
    @Test
    fun `from de Intent nulo devolve tudo vazio`() {
        val click = NotificationClickExtras.from(null)

        assertThat(click).isEqualTo(NotificationClickExtras("", "", "", "", "", "", ""))
        assertThat(click.isActionClick).isFalse()
    }

    // (h) action_id/action_label só entram no evento quando houve botão — o clique no corpo
    // continua sendo um clique sem ação, como antes.
    @Test
    fun `toUserInfo so inclui as chaves de acao quando houve botao`() {
        val body = bodyClick().toUserInfo()
        assertThat(body).doesNotContainKey(DitoNotificationActionReceiver.EXTRA_ACTION_ID)
        assertThat(body).doesNotContainKey(DitoNotificationActionReceiver.EXTRA_ACTION_LABEL)
        assertThat(body["deeplink"]).isEqualTo("myapp://home")
        assertThat(body["notification"]).isEqualTo("n1")
        assertThat(body["reference"]).isEqualTo("ref1")

        val action = actionClick().toUserInfo()
        assertThat(action[DitoNotificationActionReceiver.EXTRA_ACTION_ID]).isEqualTo("buy")
        assertThat(action[DitoNotificationActionReceiver.EXTRA_ACTION_LABEL]).isEqualTo("Comprar")
        assertThat(action["deeplink"]).isEqualTo("https://loja.example.com/carrinho")
    }
}
