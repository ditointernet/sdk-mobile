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
                if (!finished) synchronized(passLock) { passRunning = false }
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

        // O ingest descarta em silêncio um Receipt sem notification_id: reenviar só gastaria tentativas.
        val (orphanReceipts, live) = events.filter { it.retry < maxRetry }.partition {
            it.action == PUSH_RECEIVE_EVENT &&
                (mapper.customDataFromJson(it.dataJson)?.params?.get("notification_id") as? String).isNullOrEmpty()
        }
        orphanReceipts.forEach {
            Log.w("TrackerRetry", "Entrega sem notification id apagada da fila.")
            trackerOffline.delete(it.id, "Event")
        }

        val (anonymous, owned) = live.partition { it.anonymous }
        var failed = anonymous.isNotEmpty() && !sendEventsBatch(anonymous, null)
        // Cada linha sai com o user_id de quando entrou na fila; as anteriores à coluna, com o atual.
        val (withOwner, legacy) = owned.partition { it.userId != null }
        withOwner.groupBy { it.userId!! }.forEach { (owner, rows) -> if (!sendEventsBatch(rows, owner)) failed = true }
        if (legacy.isEmpty()) return failed

        val userId = tracker.awaitId() ?: run {
            Log.e("TrackerRetry", "Antes de enviar um evento é preciso identificar o usuário.")
            return failed
        }
        return !sendEventsBatch(legacy, userId) || failed
    }

    private suspend fun sendEventsBatch(events: List<EventOff>, userId: String?): Boolean {
        val activities = events.map { eventOff ->
            val event = mapper.eventFromOffline(
                eventOff.action,
                eventOff.revenue,
                eventOff.dataJson,
                eventOff.timestamp,
            )
            if (event.action == PUSH_RECEIVE_EVENT) {
                val params = event.data?.params.orEmpty()
                mapper.mapPushReceipt(
                    params["notification_id"] as? String ?: "",
                    params["dispatch_id"] as? String ?: "",
                    params["notification_name"] as? String ?: "",
                    userId ?: tracker.anonymousUserId().orEmpty(),
                    eventOff.activityId,
                    eventOff.timestamp,
                )
            } else {
                mapper.mapTrack(event, eventOff.activityId, eventOff.timestamp)
            }
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

        notifications.filter { it.retry >= maxRetry }
            .forEach { trackerOffline.delete(it.id, "NotificationRead") }

        // O identifier é o user_id do push: o clique sai com ele, logado ou não.
        val (withOwner, legacy) = notifications.filter { it.retry < maxRetry }.partition { it.identifier.isNotEmpty() }
        var failed = false
        withOwner.groupBy { it.identifier }.forEach { (owner, rows) -> if (!sendNotificationsBatch(rows, owner)) failed = true }
        if (legacy.isEmpty()) return failed

        val userId = tracker.awaitId() ?: run {
            Log.e("TrackerRetry", "Antes de enviar um evento é preciso identificar o usuário.")
            return failed
        }
        return !sendNotificationsBatch(legacy, userId) || failed
    }

    private suspend fun sendNotificationsBatch(notifications: List<NotificationReadOff>, userId: String): Boolean {
        val activities = notifications.map { notif ->
            mapper.mapNotificationClick(
                notif.notificationId,
                notif.identifier,
                notif.activityId,
                notif.data,
                notif.logId,
                notif.notificationName,
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
