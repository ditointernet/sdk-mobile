package br.com.dito.ditosdk.service

import android.content.Context
import android.os.Build
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.DitoNotificationHandler
import com.google.common.truth.Truth.assertThat
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
}
