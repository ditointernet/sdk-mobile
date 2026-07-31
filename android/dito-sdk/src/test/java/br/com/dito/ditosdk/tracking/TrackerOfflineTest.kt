package br.com.dito.ditosdk.tracking

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.Event
import br.com.dito.ditosdk.Identify
import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.util.UUID

@RunWith(RobolectricTestRunner::class)
class TrackerOfflineTest {

    private lateinit var trackerOffline: TrackerOffline
    private lateinit var context: Context

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        trackerOffline = TrackerOffline(
            context,
            useInMemoryDatabase = true,
            allowMainThreadQueries = true,
        )
    }

    @After
    fun tearDown() {
        trackerOffline.database.close()
    }

    @Test
    fun `identify should insert identify into database`() = runBlocking {
        val identify = Identify("123").apply {
            name = "n"
            email = "e"
        }

        trackerOffline.identify(identify, true)
        delay(500)

        val result = trackerOffline.getIdentify()
        assertThat(result).isNotNull()
        assertThat(result?.id).isEqualTo("123")
        assertThat(result?.send).isTrue()
    }

    @Test
    fun `identify should handle send false`() = runBlocking {
        val identify = Identify("123")

        trackerOffline.identify(identify, false)
        delay(500)

        val result = trackerOffline.getIdentify()
        assertThat(result).isNotNull()
        assertThat(result?.send).isFalse()
    }

    @Test
    fun `updateIdentify should update send status`() = runBlocking {
        val identify = Identify("123")
        trackerOffline.identify(identify, false)
        delay(500)

        trackerOffline.updateIdentify("123", true)
        delay(500)

        val result = trackerOffline.getIdentify()
        assertThat(result?.send).isTrue()
    }

    @Test
    fun `deleteIdentify should remove persisted identify`() = runBlocking {
        val identify = Identify("123")
        trackerOffline.identify(identify, true)
        delay(500)

        trackerOffline.deleteIdentify()
        delay(500)

        val result = trackerOffline.getIdentify()
        assertThat(result).isNull()
    }

    @Test
    fun `event should insert event into database`() = runBlocking {
        val event = Event("purchase")
        val aid = UUID.randomUUID().toString()

        trackerOffline.event(event, aid)
        delay(500)

        val events = trackerOffline.getAllEvents()
        assertThat(events).isNotNull()
        assertThat(events?.size).isEqualTo(1)
    }

    @Test
    fun `getAllEvents should return empty list when no events`() = runBlocking {
        val events = trackerOffline.getAllEvents()

        assertThat(events).isNull()
    }

    @Test
    fun `getAllEvents should return all events`() = runBlocking {
        val event1 = Event("purchase")
        val event2 = Event("view")
        val a1 = UUID.randomUUID().toString()
        val a2 = UUID.randomUUID().toString()

        trackerOffline.event(event1, a1)
        trackerOffline.event(event2, a2)
        delay(500)

        val events = trackerOffline.getAllEvents()
        assertThat(events).isNotNull()
        assertThat(events?.size).isEqualTo(2)
    }

    @Test
    fun `delete should remove event from database`() = runBlocking {
        val event = Event("purchase")
        val aid = UUID.randomUUID().toString()
        trackerOffline.event(event, aid)
        delay(500)

        val events = trackerOffline.getAllEvents()
        val eventId = events?.first()?.id ?: 0

        trackerOffline.delete(eventId, "Event")
        delay(500)

        val eventsAfterDelete = trackerOffline.getAllEvents()
        assertThat(eventsAfterDelete).isNull()
    }

    @Test
    fun `update should increment retry count`() = runBlocking {
        val event = Event("purchase")
        val aid = UUID.randomUUID().toString()
        trackerOffline.event(event, aid)
        delay(500)

        val events = trackerOffline.getAllEvents()
        val eventId = events?.first()?.id ?: 0

        trackerOffline.update(eventId, 1, "Event")
        delay(500)

        val updatedEvents = trackerOffline.getAllEvents()
        assertThat(updatedEvents?.first()?.retry).isEqualTo(1)
    }

    @Test
    fun `notificationRead should insert notification into database`() = runBlocking {
        trackerOffline.notificationRead("act1", "notif123", "ident123")
        delay(500)

        val notifications = trackerOffline.getAllNotificationRead()
        assertThat(notifications).isNotNull()
        assertThat(notifications?.size).isEqualTo(1)
    }

    @Test
    fun `notificationRead should round-trip the click action data`() = runBlocking {
        val actionData = mapOf("action_id" to "botao_1", "action_label" to "Botão 1")

        trackerOffline.notificationRead("act1", "notif123", "ident123", actionData)
        delay(500)

        val stored = trackerOffline.getAllNotificationRead()?.first()
        assertThat(stored?.data).isEqualTo(actionData)
    }

    @Test
    fun `notificationRead without action data should read back as empty`() = runBlocking {
        trackerOffline.notificationRead("act1", "notif123", "ident123")
        delay(500)

        val stored = trackerOffline.getAllNotificationRead()?.first()
        assertThat(stored?.data).isEmpty()
    }

    @Test
    fun `getAllNotificationRead should return empty when no notifications`() = runBlocking {
        val notifications = trackerOffline.getAllNotificationRead()

        assertThat(notifications).isNull()
    }

    @Test
    fun `delete should remove notification from database`() = runBlocking {
        trackerOffline.notificationRead("act1", "notif123", "ident123")
        delay(500)

        val notifications = trackerOffline.getAllNotificationRead()
        val notificationId = notifications?.first()?.id ?: 0

        trackerOffline.delete(notificationId, "NotificationRead")
        delay(500)

        val notificationsAfterDelete = trackerOffline.getAllNotificationRead()
        assertThat(notificationsAfterDelete).isNull()
    }

    @Test
    fun `getIdentify should return null when no identify exists`() = runBlocking {
        val result = trackerOffline.getIdentify()

        assertThat(result).isNull()
    }
}
