package br.com.dito.ditosdk.tracking

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.service.utils.EventRequest
import br.com.dito.ditosdk.service.utils.NotificationOpenRequest
import br.com.dito.ditosdk.service.utils.SigunpRequest
import br.com.dito.ditosdk.Event
import br.com.dito.ditosdk.Identify
import com.google.common.truth.Truth.assertThat
import com.google.gson.JsonObject
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

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
            allowMainThreadQueries = true
        )
    }

    @After
    fun tearDown() {
        trackerOffline.database.close()
    }

    @Test
    fun `identify should insert identify into database`() = runBlocking {
        val identify = Identify("123")
        val request = SigunpRequest("apiKey", "secret", identify)

        trackerOffline.identify(request, "ref123", true)
        delay(100)

        val result = trackerOffline.getIdentify()
        assertThat(result).isNotNull()
        assertThat(result?.id).isEqualTo("123")
        assertThat(result?.reference).isEqualTo("ref123")
        assertThat(result?.send).isTrue()
    }

    @Test
    fun `identify should handle null reference`() = runBlocking {
        val identify = Identify("123")
        val request = SigunpRequest("apiKey", "secret", identify)

        trackerOffline.identify(request, null, false)
        delay(100)

        val result = trackerOffline.getIdentify()
        assertThat(result).isNotNull()
        assertThat(result?.reference).isNull()
        assertThat(result?.send).isFalse()
    }

    @Test
    fun `updateIdentify should update send status`() = runBlocking {
        val identify = Identify("123")
        val request = SigunpRequest("apiKey", "secret", identify)
        trackerOffline.identify(request, "ref123", false)
        delay(100)

        trackerOffline.updateIdentify("123", true)
        delay(100)

        val result = trackerOffline.getIdentify()
        assertThat(result?.send).isTrue()
    }

    @Test
    fun `event should insert event into database`() = runBlocking {
        val event = Event("purchase")
        val request = EventRequest("apiKey", "secret", event)

        trackerOffline.event(request)
        delay(100)

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
        val request1 = EventRequest("apiKey", "secret", event1)
        val request2 = EventRequest("apiKey", "secret", event2)

        trackerOffline.event(request1)
        trackerOffline.event(request2)
        delay(100)

        val events = trackerOffline.getAllEvents()
        assertThat(events).isNotNull()
        assertThat(events?.size).isEqualTo(2)
    }

    @Test
    fun `delete should remove event from database`() = runBlocking {
        val event = Event("purchase")
        val request = EventRequest("apiKey", "secret", event)
        trackerOffline.event(request)
        delay(100)

        val events = trackerOffline.getAllEvents()
        val eventId = events?.first()?.id ?: 0

        trackerOffline.delete(eventId, "Event")
        delay(100)

        val eventsAfterDelete = trackerOffline.getAllEvents()
        assertThat(eventsAfterDelete).isNull()
    }

    @Test
    fun `update should increment retry count`() = runBlocking {
        val event = Event("purchase")
        val request = EventRequest("apiKey", "secret", event)
        trackerOffline.event(request)
        delay(100)

        val events = trackerOffline.getAllEvents()
        val eventId = events?.first()?.id ?: 0

        trackerOffline.update(eventId, 1, "Event")
        delay(100)

        val updatedEvents = trackerOffline.getAllEvents()
        assertThat(updatedEvents?.first()?.retry).isEqualTo(1)
    }

    @Test
    fun `notificationRead should insert notification into database`() = runBlocking {
        val data = JsonObject().apply {
            addProperty("identifier", "ident123")
            addProperty("reference", "ref123")
        }
        val request = NotificationOpenRequest("apiKey", "secret", data)

        trackerOffline.notificationRead(request)
        delay(100)

        val notifications = trackerOffline.getAllNotificationRead()
        assertThat(notifications).isNotNull()
        assertThat(notifications?.size).isEqualTo(1)
    }

    @Test
    fun `getAllNotificationRead should return empty when no notifications`() = runBlocking {
        val notifications = trackerOffline.getAllNotificationRead()

        assertThat(notifications).isNull()
    }

    @Test
    fun `delete should remove notification from database`() = runBlocking {
        val data = JsonObject().apply {
            addProperty("identifier", "ident123")
            addProperty("reference", "ref123")
        }
        val request = NotificationOpenRequest("apiKey", "secret", data)
        trackerOffline.notificationRead(request)
        delay(100)

        val notifications = trackerOffline.getAllNotificationRead()
        val notificationId = notifications?.first()?.id ?: 0

        trackerOffline.delete(notificationId, "NotificationRead")
        delay(100)

        val notificationsAfterDelete = trackerOffline.getAllNotificationRead()
        assertThat(notificationsAfterDelete).isNull()
    }

    @Test
    fun `getIdentify should return null when no identify exists`() = runBlocking {
        val result = trackerOffline.getIdentify()

        assertThat(result).isNull()
    }
}
