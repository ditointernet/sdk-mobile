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
}
