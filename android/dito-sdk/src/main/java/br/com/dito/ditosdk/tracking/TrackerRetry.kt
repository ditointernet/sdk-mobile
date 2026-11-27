package br.com.dito.ditosdk.tracking

import android.util.Log
import br.com.dito.ditosdk.EventOff
import br.com.dito.ditosdk.NotificationReadOff
import br.com.dito.ditosdk.service.ActivityMapper
import br.com.dito.ditosdk.service.MobileIngestClientInterface
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

internal class TrackerRetry(
    private val tracker: Tracker,
    private val trackerOffline: TrackerOffline,
    private val client: MobileIngestClientInterface,
    private val mapper: ActivityMapper,
    private val maxRetry: Int = 5,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
) {

    private val eventQueue = Mutex()

    fun uploadEvents() {
        scope.launch {
            // Sem device_id nada sai: a fila fica intacta, sem gastar tentativa, até ele aparecer.
            if (mapper.deviceId.isEmpty()) {
                Log.e("TrackerRetry", "device_id indisponível: reenvio da fila adiado.")
                return@launch
            }
            checkIdentify()
            checkEvent()
            checkNotificationRead()
        }
    }

    fun close() {
        scope.cancel()
    }

    private fun checkIdentify() {
        scope.launch {
            val identifyOff = trackerOffline.getIdentify() ?: return@launch
            if (identifyOff.send) return@launch
            try {
                val identify = mapper.fromIdentifyOff(identifyOff)
                val activity = mapper.mapIdentify(identify)
                val request = mapper.buildRequest(identify.id, listOf(activity), null)
                client.activity(request)
                trackerOffline.updateIdentify(identifyOff.id, true)
                if (tracker.idOrNull == identify.id) tracker.registerLastToken(identify.id)
            } catch (e: Exception) {
                Log.d("TrackerRetry", "identify retry failed: ${e.message}")
            }
        }
    }

    private fun checkEvent() {
        scope.launch {
            eventQueue.withLock {
                val events = trackerOffline.getAllEvents() ?: return@launch

                events.filter { it.retry >= maxRetry }.forEach { trackerOffline.delete(it.id, "Event") }

                val (anonymous, owned) = events.filter { it.retry < maxRetry }.partition { it.anonymous }
                if (anonymous.isNotEmpty()) {
                    sendEventsBatch(anonymous, null)
                }
                if (owned.isEmpty()) return@launch

                val userId = tracker.awaitId() ?: run {
                    Log.e("TrackerRetry", "Antes de enviar um evento é preciso identificar o usuário.")
                    return@launch
                }
                sendEventsBatch(owned, userId)
            }
        }
    }

    private suspend fun sendEventsBatch(events: List<EventOff>, userId: String?) {
        val activities = events.map { eventOff ->
            val event = mapper.eventFromOffline(
                eventOff.action,
                eventOff.revenue,
                eventOff.dataJson,
                eventOff.timestamp,
            )
            mapper.mapTrack(event, eventOff.activityId)
        }
        try {
            tracker.send(userId, activities, null)
            events.forEach { trackerOffline.delete(it.id, "Event") }
        } catch (e: Exception) {
            events.forEach { trackerOffline.update(it.id, it.retry + 1, "Event") }
        }
    }

    private fun checkNotificationRead() {
        scope.launch {
            val userId = tracker.awaitId() ?: run {
                Log.e("TrackerRetry", "Antes de enviar um evento é preciso identificar o usuário.")
                return@launch
            }
            val notifications = trackerOffline.getAllNotificationRead() ?: return@launch

            notifications.filter { it.retry >= maxRetry }
                .forEach { trackerOffline.delete(it.id, "NotificationRead") }

            val toSend = notifications.filter { it.retry < maxRetry }
            if (toSend.isEmpty()) return@launch

            sendNotificationsBatch(toSend, userId)
        }
    }

    private suspend fun sendNotificationsBatch(notifications: List<NotificationReadOff>, userId: String) {
        val activities = notifications.map { notif ->
            mapper.mapNotificationClick(
                notif.notificationId,
                notif.identifier,
                notif.activityId,
                notif.data,
            )
        }
        try {
            val request = mapper.buildRequest(userId, activities, null)
            client.activity(request)
            notifications.forEach { trackerOffline.delete(it.id, "NotificationRead") }
        } catch (e: Exception) {
            notifications.forEach { trackerOffline.update(it.id, it.retry + 1, "NotificationRead") }
        }
    }
}
