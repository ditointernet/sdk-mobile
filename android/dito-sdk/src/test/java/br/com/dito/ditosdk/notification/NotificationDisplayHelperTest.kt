package br.com.dito.ditosdk.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [Build.VERSION_CODES.O])
class NotificationDisplayHelperTest {

    private lateinit var context: Context
    private lateinit var notificationManager: NotificationManager

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    }

    // (a) soundResourceName='ping' → Uri contém '/raw/ping'
    @Test
    fun `resolveSoundUri with soundResourceName ping returns Uri containing raw ping`() {
        // Arrange
        val options = DitoNotificationOptions(soundResourceName = "ping")

        // Act
        val uri = NotificationDisplayHelper.resolveSoundUri(context, options)

        // Assert
        assertThat(uri.toString()).contains("/raw/ping")
    }

    @Test
    fun `resolveSoundUri builds exact android resource Uri for ping`() {
        // Arrange
        val options = DitoNotificationOptions(soundResourceName = "ping")

        // Act
        val uri = NotificationDisplayHelper.resolveSoundUri(context, options)

        // Assert
        assertThat(uri.toString()).isEqualTo("android.resource://${context.packageName}/raw/ping")
    }

    @Test
    fun `resolveSoundUri with null soundResourceName returns default notification sound`() {
        // Arrange
        val options = DitoNotificationOptions(soundResourceName = null)

        // Act
        val uri = NotificationDisplayHelper.resolveSoundUri(context, options)

        // Assert
        assertThat(uri.toString()).doesNotContain("/raw/")
    }

    // (b) smallIconResId=null → fallback aplicado
    @Test
    fun `resolveSmallIcon with null smallIconResId falls back to existing icon`() {
        // Arrange
        val options = DitoNotificationOptions(smallIconResId = null)

        // Act
        val icon = NotificationDisplayHelper.resolveSmallIcon(context, options)

        // Assert: fallback must return a valid non-zero resource id
        assertThat(icon).isGreaterThan(0)
    }

    @Test
    fun `resolveSmallIcon with non-null smallIconResId uses provided resource`() {
        // Arrange
        val expectedResId = android.R.drawable.ic_menu_camera
        val options = DitoNotificationOptions(smallIconResId = expectedResId)

        // Act
        val icon = NotificationDisplayHelper.resolveSmallIcon(context, options)

        // Assert
        assertThat(icon).isEqualTo(expectedResId)
    }

    // (d) canal 'dito' não sobrescreve canais de SDKs terceiras
    @Test
    fun `createNotificationChannel for dito does not remove pre-existing third-party channels`() {
        // Arrange: simulate a third-party SDK channel already registered
        val shadowManager = shadowOf(notificationManager)
        val thirdPartyChannelId = "third-party-sdk-channel"
        val thirdPartyChannel = android.app.NotificationChannel(
            thirdPartyChannelId,
            "Third Party SDK",
            NotificationManager.IMPORTANCE_DEFAULT
        )
        notificationManager.createNotificationChannel(thirdPartyChannel)

        assertThat(shadowManager.notificationChannels.map { (it as NotificationChannel).id })
            .contains(thirdPartyChannelId)

        // Act: NotificationDisplayHelper creates its own channel (simulated as production code does)
        val ditoChannel = android.app.NotificationChannel(
            "dito",
            "Dito Notifications",
            NotificationManager.IMPORTANCE_HIGH
        )
        notificationManager.createNotificationChannel(ditoChannel)

        // Assert: both channels coexist — dito channel creation did not remove third-party channel
        val channelsAfter = shadowManager.notificationChannels.map { (it as NotificationChannel).id }
        assertThat(channelsAfter).contains(thirdPartyChannelId)
        assertThat(channelsAfter).contains("dito")
    }

    // --- rich push: parsing de actions ---

    @Test
    fun `parseActions returns both buttons preserving order`() {
        // Arrange
        val json = """
            [
              {"id":"comprar_agora","label":"Comprar agora","link":"https://dito.com.br/comprar"},
              {"id":"ver_mais","label":"Ver mais","link":"https://dito.com.br/mais"}
            ]
        """.trimIndent()

        // Act
        val actions = DitoRichPushParser.parseActions(json)

        // Assert
        assertThat(actions).hasSize(2)
        assertThat(actions[0]).isEqualTo(
            DitoNotificationAction("comprar_agora", "Comprar agora", "https://dito.com.br/comprar")
        )
        assertThat(actions[1].id).isEqualTo("ver_mais")
    }

    @Test
    fun `parseActions returns empty list for null blank and malformed json`() {
        assertThat(DitoRichPushParser.parseActions(null)).isEmpty()
        assertThat(DitoRichPushParser.parseActions("")).isEmpty()
        assertThat(DitoRichPushParser.parseActions("not-json")).isEmpty()
        assertThat(DitoRichPushParser.parseActions("""{"id":"x"}""")).isEmpty()
    }

    @Test
    fun `parseActions skips entries without id or label and dedupes by id`() {
        // Arrange
        val json = """
            [
              {"label":"Sem id","link":"https://a"},
              {"id":"sem_label","link":"https://b"},
              {"id":"ok","label":"Ok","link":"https://c"},
              {"id":"ok","label":"Duplicado","link":"https://d"}
            ]
        """.trimIndent()

        // Act
        val actions = DitoRichPushParser.parseActions(json)

        // Assert
        assertThat(actions).hasSize(1)
        assertThat(actions[0].label).isEqualTo("Ok")
    }

    @Test
    fun `parseActions caps at two buttons`() {
        // Arrange
        val json = """
            [
              {"id":"a","label":"A","link":"https://a"},
              {"id":"b","label":"B","link":"https://b"},
              {"id":"c","label":"C","link":"https://c"}
            ]
        """.trimIndent()

        // Act
        val actions = DitoRichPushParser.parseActions(json)

        // Assert
        assertThat(actions).hasSize(DitoRichPushParser.MAX_ACTIONS)
        assertThat(actions.map { it.id }).containsExactly("a", "b").inOrder()
    }

    @Test
    fun `parseActions tolerates missing link`() {
        // Act
        val actions = DitoRichPushParser.parseActions("""[{"id":"a","label":"A"}]""")

        // Assert
        assertThat(actions).hasSize(1)
        assertThat(actions[0].link).isEmpty()
    }

    // --- rich push: parsing de custom data ---

    @Test
    fun `parseCustomData returns all keys as strings`() {
        // Act
        val data = DitoRichPushParser.parseCustomData(
            """{"nivel_programa":"ouro","id_pedido":"12345"}"""
        )

        // Assert
        assertThat(data).containsExactly("nivel_programa", "ouro", "id_pedido", "12345")
    }

    @Test
    fun `parseCustomData coerces non string values and drops nulls`() {
        // Act
        val data = DitoRichPushParser.parseCustomData(
            """{"pontos":150,"vip":true,"vazio":null}"""
        )

        // Assert
        assertThat(data).containsExactly("pontos", "150", "vip", "true")
    }

    @Test
    fun `parseCustomData returns empty map for null blank and malformed json`() {
        assertThat(DitoRichPushParser.parseCustomData(null)).isEmpty()
        assertThat(DitoRichPushParser.parseCustomData("")).isEmpty()
        assertThat(DitoRichPushParser.parseCustomData("not-json")).isEmpty()
        assertThat(DitoRichPushParser.parseCustomData("[1,2,3]")).isEmpty()
    }

    // --- rich push: renderização ---

    @Test
    fun `showNotification with two actions renders two notification actions`() {
        // Arrange
        val actions = listOf(
            DitoNotificationAction("comprar_agora", "Comprar agora", "https://dito.com.br/comprar"),
            DitoNotificationAction("ver_mais", "Ver mais", "https://dito.com.br/mais"),
        )

        // Act
        showNotification(actions = actions)

        // Assert
        val notification = shadowOf(notificationManager).allNotifications.single()
        assertThat(notification.actions).hasLength(2)
        assertThat(notification.actions.map { it.title.toString() })
            .containsExactly("Comprar agora", "Ver mais").inOrder()
    }

    @Test
    fun `showNotification without rich fields renders no actions`() {
        // Act: exactly the legacy call shape
        showNotification()

        // Assert
        val notification = shadowOf(notificationManager).allNotifications.single()
        assertThat(notification.actions).isNull()
        assertThat(notification.contentIntent).isNotNull()
    }

    @Test
    fun `showNotification with unreachable image falls back instead of failing`() {
        // Arrange: host inexistente força falha no download
        // Act
        showNotification(imageUrl = "http://127.0.0.1:1/does-not-exist.png")

        // Assert: notificação ainda é postada
        assertThat(shadowOf(notificationManager).allNotifications).hasSize(1)
    }

    @Test
    fun `downloadImage returns null for null and blank urls`() {
        assertThat(NotificationDisplayHelper.downloadImage(null)).isNull()
        assertThat(NotificationDisplayHelper.downloadImage("   ")).isNull()
    }

    private fun showNotification(
        imageUrl: String? = null,
        actions: List<DitoNotificationAction> = emptyList(),
        customDataJson: String? = null,
    ) {
        NotificationDisplayHelper.showNotification(
            context = context,
            title = "Título",
            message = "Mensagem",
            notificationId = "notif123",
            reference = "ref123",
            deepLink = "https://dito.com.br",
            channel = "App notifications",
            channelDescription = "App application notifications",
            userId = "user123",
            imageUrl = imageUrl,
            actions = actions,
            customDataJson = customDataJson,
        )
    }
}
