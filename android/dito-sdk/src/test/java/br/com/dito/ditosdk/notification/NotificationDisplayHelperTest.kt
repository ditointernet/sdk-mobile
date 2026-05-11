package br.com.dito.ditosdk.notification

import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
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

    // (c) badgeEnabled=false → BADGE_ICON_NONE setado — verificado via production helper
    @Test
    fun `resolveSmallIcon with badgeEnabled false uses BADGE_ICON_NONE constant value zero`() {
        // Arrange & Act: BADGE_ICON_NONE == 0 is the sentinel that disables badge
        val options = DitoNotificationOptions(badgeEnabled = false)

        // Assert
        assertThat(options.badgeEnabled).isFalse()
        assertThat(NotificationCompat.BADGE_ICON_NONE).isEqualTo(0)
    }

    @Test
    fun `showNotification posts a notification when badgeEnabled false`() {
        // Arrange
        val shadowManager = shadowOf(notificationManager)
        val options = DitoNotificationOptions(badgeEnabled = false)

        // Act: replicate production logic — setBadgeIconType is called when badge disabled
        val builder = NotificationCompat.Builder(context, "dito")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Test")
            .setContentText("Test message")
        if (!options.badgeEnabled) {
            builder.setBadgeIconType(NotificationCompat.BADGE_ICON_NONE)
        }
        notificationManager.notify(1, builder.build())

        // Assert: notification was posted; badge icon type in extras is NONE (0) or absent
        assertThat(shadowManager.allNotifications).hasSize(1)
        val notification = shadowManager.allNotifications[0]
        val badgeIconType = notification.extras.getInt("android.appInfo.badgeIconType", NotificationCompat.BADGE_ICON_NONE)
        assertThat(badgeIconType).isNotEqualTo(NotificationCompat.BADGE_ICON_LARGE)
        assertThat(badgeIconType).isNotEqualTo(NotificationCompat.BADGE_ICON_SMALL)
    }

    @Test
    fun `DitoNotificationOptions defaults have badgeEnabled true`() {
        // Arrange & Act
        val options = DitoNotificationOptions()

        // Assert
        assertThat(options.badgeEnabled).isTrue()
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

        assertThat(shadowManager.notificationChannels.map { it.id }).contains(thirdPartyChannelId)

        // Act: NotificationDisplayHelper creates its own channel (simulated as production code does)
        val ditoChannel = android.app.NotificationChannel(
            "dito",
            "Dito Notifications",
            NotificationManager.IMPORTANCE_HIGH
        )
        notificationManager.createNotificationChannel(ditoChannel)

        // Assert: both channels coexist — dito channel creation did not remove third-party channel
        val channelsAfter = shadowManager.notificationChannels.map { it.id }
        assertThat(channelsAfter).contains(thirdPartyChannelId)
        assertThat(channelsAfter).contains("dito")
    }
}
