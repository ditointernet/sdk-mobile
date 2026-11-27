package br.com.dito.ditosdk.tracking

import android.os.SystemClock
import android.util.Log
import br.com.dito.ditosdk.EventOff
import br.com.dito.ditosdk.NotificationReadOff
import br.com.dito.ditosdk.service.ActivityMapper
import br.com.dito.ditosdk.service.MobileIngestClientInterface
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

internal class TrackerRetry(
    private val tracker: Tracker,
    private val trackerOffline: TrackerOffline,
    private val client: MobileIngestClientInterface,
    private val mapper: ActivityMapper,
    private val maxRetry: Int = 5,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
    private val isOnline: () -> Boolean = { true },
    private val now: () -> Long = SystemClock::elapsedRealtime,
) {

    private val passLock = Any()
    private var passRunning = false
    private var nextPass = false
    private var nextPassIgnoresBackoff = false
    private var failedAt: Long? = null
    private var scheduledPass: Job? = null

    fun uploadEvents() = requestPass(ignoringBackoff = false)

    // Rede nova: uma falha anterior não diz nada sobre esta passada.
    fun uploadEventsOnReconnect() = requestPass(ignoringBackoff = true)

    // Envio ao vivo deu certo: o backend voltou e a espera da última falha não vale mais.
    fun uploadEventsAfterLiveSuccess() {
        synchronized(passLock) { failedAt = null }
        requestPass(ignoringBackoff = true)
    }

    // Uma passada por vez, para nenhuma linha sair em dobro; pedido no meio de uma passada enfileira
    // uma só. Depois de uma falha que gastou tentativa, as passadas esperam a trava (cada passada que
    // falha gasta uma tentativa de cada linha) e uma pulada roda uma vez no fim dela.
    private fun requestPass(ignoringBackoff: Boolean) {
        synchronized(passLock) {
            if (ignoringBackoff) {
                scheduledPass?.cancel()
                scheduledPass = null
            } else if (inBackoff()) {
                Log.w("TrackerRetry", "Passada adiada: houve falha de envio há menos de ${BACKOFF_MS / 1000}s.")
                schedulePassAfterBackoff()
                return
            }
            if (passRunning) {
                nextPass = true
                nextPassIgnoresBackoff = nextPassIgnoresBackoff || ignoringBackoff
                return
            }
            passRunning = true
        }
        scope.launch {
            var finished = false
            try {
                while (!finished) finished = !finishPass(runPass())
            } finally {
                // Exceção ou cancelamento no meio da passada não pode deixar as próximas travadas.
                if (!finished) synchronized(passLock) {
                    passRunning = false
                    nextPass = false
                    nextPassIgnoresBackoff = false
                }
            }
        }
    }

    /** Fecha a passada; `true` se a enfileirada deve rodar agora. */
    private fun finishPass(failed: Boolean?): Boolean = synchronized(passLock) {
        if (failed != null) failedAt = if (failed) now() else null
        var again = nextPass
        if (again && !nextPassIgnoresBackoff && inBackoff()) {
            schedulePassAfterBackoff()
            again = false
        }
        nextPass = false
        nextPassIgnoresBackoff = false
        passRunning = again
        again
    }

    /** Com [passLock]. */
    private fun inBackoff(): Boolean = failedAt?.let { now() - it < BACKOFF_MS } ?: false

    /** Com [passLock]. */
    private fun schedulePassAfterBackoff() {
        val at = failedAt ?: return
        if (scheduledPass?.isActive == true) return
        scheduledPass = scope.launch {
            delay(at + BACKOFF_MS - now())
            // Cancelado depois do delay (reconexão) ou já substituído: não roda nem mexe no novo.
            val current = synchronized(passLock) {
                (scheduledPass === coroutineContext[Job]).also { if (it) scheduledPass = null }
            }
            // Sem rede só gastaria uma tentativa de cada linha; a reconexão faz a passada.
            if (current && isOnline()) uploadEvents()
        }
    }

    /** `true` se algum envio falhou e gastou tentativa; `null` se a passada não rodou. */
    private suspend fun runPass(): Boolean? {
        // Sem device_id nada sai: a fila fica intacta, sem gastar tentativa, até ele aparecer.
        if (mapper.deviceId.isEmpty()) {
            Log.e("TrackerRetry", "device_id indisponível: reenvio da fila adiado.")
            return null
        }
        checkIdentify()
        val eventsFailed = checkEvent()
        val clicksFailed = checkNotificationRead()
        return eventsFailed || clicksFailed
    }

    fun close() {
        scope.cancel()
    }

    private suspend fun checkIdentify() {
        val identifyOff = trackerOffline.getIdentify() ?: return
        if (identifyOff.send) return
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

    private suspend fun checkEvent(): Boolean {
        val events = trackerOffline.getAllEvents() ?: return false

        events.filter { it.retry >= maxRetry }.forEach { trackerOffline.delete(it.id, "Event") }

        val (anonymous, owned) = events.filter { it.retry < maxRetry }.partition { it.anonymous }
        val anonymousFailed = anonymous.isNotEmpty() && !sendEventsBatch(anonymous, null)
        if (owned.isEmpty()) return anonymousFailed

        val userId = tracker.awaitId() ?: run {
            Log.e("TrackerRetry", "Antes de enviar um evento é preciso identificar o usuário.")
            return anonymousFailed
        }
        return !sendEventsBatch(owned, userId) || anonymousFailed
    }

    private suspend fun sendEventsBatch(events: List<EventOff>, userId: String?): Boolean {
        val activities = events.map { eventOff ->
            val event = mapper.eventFromOffline(
                eventOff.action,
                eventOff.revenue,
                eventOff.dataJson,
                eventOff.timestamp,
            )
            mapper.mapTrack(event, eventOff.activityId, eventOff.timestamp)
        }
        return try {
            tracker.send(userId, activities, null)
            events.forEach { trackerOffline.delete(it.id, "Event") }
            true
        } catch (e: Exception) {
            events.forEach { trackerOffline.update(it.id, it.retry + 1, "Event") }
            false
        }
    }

    private suspend fun checkNotificationRead(): Boolean {
        val notifications = trackerOffline.getAllNotificationRead() ?: return false
        val userId = tracker.awaitId() ?: run {
            Log.e("TrackerRetry", "Antes de enviar um evento é preciso identificar o usuário.")
            return false
        }

        notifications.filter { it.retry >= maxRetry }
            .forEach { trackerOffline.delete(it.id, "NotificationRead") }

        val toSend = notifications.filter { it.retry < maxRetry }
        if (toSend.isEmpty()) return false

        return !sendNotificationsBatch(toSend, userId)
    }

    private suspend fun sendNotificationsBatch(notifications: List<NotificationReadOff>, userId: String): Boolean {
        val activities = notifications.map { notif ->
            mapper.mapNotificationClick(
                notif.notificationId,
                notif.identifier,
                notif.activityId,
                notif.data,
            )
        }
        return try {
            val request = mapper.buildRequest(userId, activities, null)
            client.activity(request)
            notifications.forEach { trackerOffline.delete(it.id, "NotificationRead") }
            true
        } catch (e: Exception) {
            notifications.forEach { trackerOffline.update(it.id, it.retry + 1, "NotificationRead") }
            false
        }
    }

    private companion object {
        const val BACKOFF_MS = 60_000L
    }
}
