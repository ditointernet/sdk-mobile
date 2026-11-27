package br.com.dito.ditosdk.service

import android.content.Context
import android.os.Build
import android.provider.Settings
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.DitoNotificationHandler
import br.com.dito.ditosdk.Event
import br.com.dito.ditosdk.tracking.Tracker
import com.google.common.truth.Truth.assertThat
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [Build.VERSION_CODES.O])
class ActivityMapperTest {

    private lateinit var mapper: ActivityMapper

    @Before
    fun setup() {
        mapper = ActivityMapper(ApplicationProvider.getApplicationContext<Context>())
    }

    @Test
    fun `empty device id should not be cached and is read again on the next call`() {
        setAndroidId("")
        assertThat(mapper.deviceId).isEmpty()

        setAndroidId("device-1")
        assertThat(mapper.deviceId).isEqualTo("device-1")

        setAndroidId("device-2")
        assertThat(mapper.deviceId).isEqualTo("device-1")
    }

    @Test
    fun `buildRequest should refuse to build a request without device id`() {
        setAndroidId("")

        assertThrows(DeviceIdUnavailableException::class.java) {
            mapper.buildRequest("user1", emptyList(), null)
        }
    }

    @Test
    fun `buildRequest should carry the device id`() {
        setAndroidId("device-1")

        assertThat(mapper.buildRequest("", emptyList(), null).device.deviceId).isEqualTo("device-1")
    }

    @Test
    fun `mapTrack should use the queued time on resend`() {
        val activity = mapper.mapTrack(Event("purchase"), "a1", queuedAt = "2026-11-27T10:00:00-0300")

        assertThat(activity.timestamp.seconds).isEqualTo(java.time.Instant.parse("2026-11-27T13:00:00Z").epochSecond)
    }

    @Test
    fun `mapTrack should keep the milliseconds of the queued time`() {
        val activity = mapper.mapTrack(Event("purchase"), "a1", queuedAt = "2026-11-27T10:00:00.250-0300")

        assertThat(activity.timestamp.seconds).isEqualTo(java.time.Instant.parse("2026-11-27T13:00:00Z").epochSecond)
        assertThat(activity.timestamp.nanos).isEqualTo(250_000_000)
    }

    @Test
    fun `mapTrack without a valid queued time should use the current time`() {
        val before = java.time.Instant.now().epochSecond

        listOf(null, "", "2026-13-45").forEach { queuedAt ->
            val activity = mapper.mapTrack(Event("purchase"), "a1", queuedAt = queuedAt)
            assertThat(activity.timestamp.seconds).isAtLeast(before)
        }
    }

    @Test
    fun `live mapTrack should use the current time, not the event createdAt`() {
        val before = java.time.Instant.now().epochSecond
        val event = Event("purchase").apply { createdAt = "2020-01-01T10:00:00-0300" }

        assertThat(mapper.mapTrack(event).timestamp.seconds).isAtLeast(before)
    }

    @Test
    fun `device id showing up after an empty read should notify once`() {
        var notified = 0
        mapper.onDeviceIdAvailable = { notified++ }
        setAndroidId("")
        mapper.deviceId

        setAndroidId("device-1")
        mapper.deviceId
        mapper.deviceId

        assertThat(notified).isEqualTo(1)
    }

    @Test
    fun `device id available from the start should not notify`() {
        var notified = 0
        mapper.onDeviceIdAvailable = { notified++ }
        setAndroidId("device-1")

        mapper.deviceId

        assertThat(notified).isEqualTo(0)
    }

    @Test
    fun `flush read of a device id that showed up should not notify`() {
        var notified = 0
        mapper.onDeviceIdAvailable = { notified++ }
        setAndroidId("")
        mapper.deviceId

        setAndroidId("device-1")
        assertThat(mapper.deviceIdForFlush()).isEqualTo("device-1")
        mapper.deviceId

        assertThat(notified).isEqualTo(0)
    }

    private fun setAndroidId(value: String) {
        Settings.Secure.putString(
            ApplicationProvider.getApplicationContext<Context>().contentResolver,
            Settings.Secure.ANDROID_ID,
            value,
        )
    }

    @Test
    fun `mapNotificationClick without data keeps the payload empty`() {
        // Act
        val activity = mapper.mapNotificationClick("notif1", "user1")

        // Assert: clique no corpo continua idêntico ao que já era enviado
        assertThat(activity.trackPushClick.dataMap).isEmpty()
        assertThat(activity.trackPushClick.notification.notificationId).isEqualTo("notif1")
        assertThat(activity.trackPushClick.notification.identifier).isEqualTo("user1")
    }

    @Test
    fun `mapNotificationClick carries action id and label in the data map`() {
        // Arrange
        val data = mapOf("action_id" to "comprar_agora", "action_label" to "Comprar agora")

        // Act
        val activity = mapper.mapNotificationClick("notif1", "user1", "activity1", data)

        // Assert
        val dataMap = activity.trackPushClick.dataMap
        assertThat(dataMap.keys).containsExactly("action_id", "action_label")
        assertThat(dataMap["action_id"]?.single?.stringValue).isEqualTo("comprar_agora")
        assertThat(dataMap["action_label"]?.single?.stringValue).isEqualTo("Comprar agora")
        assertThat(activity.id).isEqualTo("activity1")
    }

    @Test
    fun `extractClickData only produces data for button clicks`() {
        // Arrange
        val bodyClick = mapOf("notification" to "notif1", "reference" to "ref1")
        val buttonClick = bodyClick + mapOf(
            "action_id" to "comprar_agora",
            "action_label" to "Comprar agora",
        )

        // Act + Assert
        assertThat(DitoNotificationHandler.extractClickData(bodyClick)).isEmpty()
        assertThat(DitoNotificationHandler.extractClickData(buttonClick)).containsExactly(
            "action_id", "comprar_agora",
            "action_label", "Comprar agora",
        )
    }

    @Test
    fun `handleClick passes log id and notification name from the userInfo to the tracker`() {
        val tracker = mockk<Tracker>(relaxed = true)
        val userInfo = mapOf(
            "notification" to "notif1",
            "reference" to "ref1",
            "user_id" to "user1",
            "log_id" to "log1",
            "notification_name" to "Campanha",
        )

        DitoNotificationHandler.handleClick(userInfo, null, tracker)

        verify { tracker.notificationClick("notif1", "ref1", "user1", emptyMap(), "log1", "Campanha") }
    }

    @Test
    fun `mapNotificationClick carries dispatch id, name and the mobile channel`() {
        val activity = mapper.mapNotificationClick(
            "notif1",
            "user1",
            logId = "log1",
            notificationName = "Campanha",
        )

        val info = activity.trackPushClick.notification
        assertThat(info.dispatchId).isEqualTo("log1")
        assertThat(info.name).isEqualTo("Campanha")
        assertThat(info.channel).isEqualTo("mobile")
    }

    @Test
    fun `mapNotificationClick without log id still sends the mobile channel`() {
        val info = mapper.mapNotificationClick("notif1", "user1").trackPushClick.notification

        assertThat(info.dispatchId).isEmpty()
        assertThat(info.name).isEmpty()
        assertThat(info.channel).isEqualTo("mobile")
    }

    @Test
    fun `mapPushReceipt fills the notification info`() {
        val activity = mapper.mapPushReceipt("notif1", "log1", "Campanha", "user1", "activity1")

        assertThat(activity.id).isEqualTo("activity1")
        assertThat(activity.hasTrackPushReceipt()).isTrue()
        val info = activity.trackPushReceipt.notification
        assertThat(info.notificationId).isEqualTo("notif1")
        assertThat(info.dispatchId).isEqualTo("log1")
        assertThat(info.name).isEqualTo("Campanha")
        assertThat(info.identifier).isEqualTo("user1")
        assertThat(info.channel).isEqualTo("mobile")
    }
}
