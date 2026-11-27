package br.com.dito.ditosdk.tracking

import android.util.Log
import br.com.dito.ditosdk.BuildConfig
import br.com.dito.ditosdk.CustomData
import br.com.dito.ditosdk.Dito
import br.com.dito.ditosdk.Event
import br.com.dito.ditosdk.Identify
import br.com.dito.ditosdk.service.ActivityMapper
import br.com.dito.ditosdk.service.MobileIngestClientInterface
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import mobileingest.v1.Api
import java.security.MessageDigest
import java.util.UUID

internal const val PUSH_RECEIVE_EVENT = "receive-android-notification"

internal class Tracker(
    private val trackerOffline: TrackerOffline,
    private val client: MobileIngestClientInterface,
    private val mapper: ActivityMapper,
    private val anonymousState: AnonymousState,
    private val debug: Boolean = false,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
) {

    @Volatile
    var id: String? = null
    private var trackerRetry: TrackerRetry? = null
    private var connectivityTrigger: ConnectivityRetryTrigger? = null

    // Declarados antes de identifyLoad: o load pode rodar em outra thread ainda durante o init.
    private val idLock = Any()
    private var loggedOut = false
    private var logouts = 0
    private val anonymousSend = Mutex()
    private val identifyDisk = Mutex()
    private val tokenState = Mutex()

    /**
     * Carregamento do identify persistido, exposto como [Job] para que quem depende do `id` possa
     * esperá-lo. No cold start o flush da fila offline corre em paralelo com este carregamento: sem
     * poder esperar, ele lia `id == null` e voltava sem drenar nada — justamente no ciclo do push,
     * que é quando a fila mais importa.
     */
    private val identifyLoad: Job = loadIdentify()

    val idOrNull: String? get() = id

    fun setTrackerRetry(retry: TrackerRetry) {
        this.trackerRetry = retry
    }

    fun setConnectivityTrigger(trigger: ConnectivityRetryTrigger) {
        this.connectivityTrigger = trigger
    }

    fun close() {
        connectivityTrigger?.close()
        trackerRetry?.close()
        scope.cancel()
    }

    private fun loadIdentify(): Job = scope.launch {
        val stored = trackerOffline.getIdentify()?.id?.takeIf { it.isNotBlank() }
        // Um `identify()` ou `logout()` concorrente é mais novo que o disco: não sobrescreve.
        synchronized(idLock) { if (id == null && !loggedOut) id = stored }
    }

    /**
     * `id` depois de garantido o carregamento do identify persistido. Qualquer caminho que possa
     * rodar no arranque do processo deve usar isto, e não [idOrNull].
     */
    internal suspend fun awaitId(): String? {
        identifyLoad.join()
        return id
    }

    enum class OperationStatus {
        SENT,
        SAVED_LOCALLY,
    }

    fun identify(identify: Identify, callback: ((OperationStatus?, Throwable?) -> Unit)?) {
        if (identify.id.isBlank()) {
            val error = IllegalArgumentException("O id do identify não pode ser vazio.")
            Log.e("Tracker", error.message ?: "")
            callback?.invoke(null, error)
            return
        }
        synchronized(idLock) { id = identify.id }
        scope.launch {
            if (debug) Log.d("Tracker", "begin identify user: ${identify.id}")
            // Se o device_id aparecer agora, a fila só drena depois deste request, não em paralelo.
            val deviceIdArrived = mapper.claimDeviceIdArrival()
            val activity = mapper.mapIdentify(identify)
            try {
                client.activity(mapper.buildRequest(identify.id, listOf(activity), null))
                val current = persistIfCurrent(identify, send = true)
                callback?.invoke(OperationStatus.SENT, null)
                if (current) registerLastToken(identify.id)
                if (current || deviceIdArrived) trackerRetry?.uploadEventsAfterLiveSuccess()
            } catch (e: Exception) {
                if (debug) Log.d("Tracker", "identify error: $e", e)
                persistIfCurrent(identify, send = false)
                callback?.invoke(null, e)
                if (deviceIdArrived) trackerRetry?.uploadEvents()
            }
        }
    }

    // Um logout() ou outro identify() durante o request não pode ter o disco sobrescrito por este usuário.
    private suspend fun persistIfCurrent(identify: Identify, send: Boolean): Boolean = identifyDisk.withLock {
        (id == identify.id).also { if (it) trackerOffline.identify(identify, send) }
    }

    fun event(event: Event, callback: ((OperationStatus?, Throwable?) -> Unit)? = null) {
        scope.launch {
            val activityId = UUID.randomUUID().toString()
            val userId = awaitId()
            val activity = mapper.mapTrack(event, activityId, event.createdAt)
            try {
                send(userId, listOf(activity), null)
                callback?.invoke(OperationStatus.SENT, null)
            } catch (e: Exception) {
                handleEventError(e, event, activityId, userId)
                callback?.invoke(OperationStatus.SAVED_LOCALLY, null)
            }
        }
    }

    private fun handleEventError(exception: Exception, event: Event, activityId: String, userId: String?) {
        if (exception is UninitializedPropertyAccessException) {
            Log.e("Tracker", "Antes de enviar um evento é preciso identificar o usuário.")
        }
        trackerOffline.event(event, activityId, anonymous = userId == null, userId = userId)
    }

    /** @param identifyFirst sem identify pendente deste usuário, manda antes um identify só com o id. */
    internal suspend fun send(userId: String?, activities: List<Api.Activity>, token: String?, identifyFirst: Boolean = false) {
        if (userId == null) {
            sendAnonymous(activities, token)
            return
        }
        // Identify deste usuário ainda não enviado vai antes, no mesmo request: o backend não pode
        // receber atividade de um user_id que ainda não conhece.
        val pending = identifyDisk.withLock { trackerOffline.getIdentify() }?.takeIf { it.id == userId && !it.send }
        if (pending == null) {
            val all = if (identifyFirst) listOf(mapper.mapIdentify(Identify(userId))) + activities else activities
            client.activity(mapper.buildRequest(userId, all, token))
            return
        }
        val identify = mapper.mapIdentify(mapper.fromIdentifyOff(pending))
        client.activity(mapper.buildRequest(userId, listOf(identify) + activities, token))
        identifyDisk.withLock { if (trackerOffline.getIdentify() == pending) trackerOffline.updateIdentify(userId, true) }
        // Como no reenvio do identify pela fila; um register neste request já levou o token.
        if (id == userId && activities.none { it.hasTokenRegister() }) registerLastToken(userId)
    }

    // user_id "" vai com o device_id: é por ele que o backend resolve o usuário.
    private suspend fun sendAnonymous(activities: List<Api.Activity>, token: String?) {
        val mark = "${mapper.requireDeviceId()}|${BuildConfig.DITO_SDK_VERSION}"
        if (anonymousState.identifyMark == mark) {
            client.activity(mapper.buildRequest("", activities, token))
            return
        }
        anonymousSend.withLock {
            val withIdentify = anonymousState.identifyMark != mark
            val all = if (withIdentify) listOf(mapper.mapAnonymousIdentify()) + activities else activities
            client.activity(mapper.buildRequest("", all, token))
            if (withIdentify) anonymousState.identifyMark = mark
        }
    }

    private suspend fun registerFor(userId: String, token: String) {
        val session = synchronized(idLock) { logouts }
        send(userId, listOf(mapper.mapTokenRegister(token)), token)
        // Um unregisterToken() ou logout() concorrente não pode ser desfeito pela confirmação.
        tokenState.withLock {
            synchronized(idLock) {
                if (logouts == session && id == userId && anonymousState.lastToken == token) {
                    anonymousState.setConfirmed(userId, token)
                }
            }
        }
    }

    internal suspend fun registerLastToken(userId: String) {
        val token = anonymousState.lastToken ?: return
        val confirmed = synchronized(idLock) {
            anonymousState.confirmedUserId == userId && anonymousState.confirmedToken == token
        }
        if (confirmed) return
        try {
            registerFor(userId, token)
        } catch (e: Exception) {
            Log.e("Tracker", "Falha ao reenviar o token após o identify.", e)
        }
    }

    fun registerToken(token: String, callback: ((OperationStatus?, Throwable?) -> Unit)? = null) {
        scope.launch {
            try {
                val userId = awaitId()
                anonymousState.lastToken = token
                try {
                    if (userId == null) send(null, listOf(mapper.mapTokenRegister(token)), token) else registerFor(userId, token)
                } finally {
                    // Um identify() que terminou antes de lastToken ser gravado não reenviou este token.
                    if (userId == null) id?.let { registerLastToken(it) }
                }
                callback?.invoke(OperationStatus.SENT, null)
            } catch (e: Exception) {
                if (debug) Log.d("Tracker", "registerToken error: $e", e)
                callback?.invoke(null, e)
            }
        }
    }

    fun unregisterToken(token: String, callback: ((OperationStatus?, Throwable?) -> Unit)? = null) {
        scope.launch {
            try {
                val userId = awaitId()
                mapper.requireDeviceId()
                tokenState.withLock {
                    if (anonymousState.lastToken == token) anonymousState.lastToken = null
                    if (anonymousState.confirmedToken == token) anonymousState.setConfirmed(null, null)
                }
                send(userId, listOf(mapper.mapTokenUnregister(token)), token)
                callback?.invoke(OperationStatus.SENT, null)
            } catch (e: Exception) {
                Log.e("Tracker", e.message, e)
                callback?.invoke(null, e)
            }
        }
    }

    fun logout() {
        synchronized(idLock) {
            loggedOut = true
            logouts++
            id = null
            // Como no iOS: o próximo login reenvia o token.
            anonymousState.setConfirmed(null, null)
        }
        scope.launch {
            // Um identify() do mesmo usuário feito depois deste logout já está no disco: não apagar.
            identifyDisk.withLock {
                if (id == null || trackerOffline.getIdentify()?.id != id) trackerOffline.deleteIdentify()
            }
        }
    }

    /** Usa o user_id do payload só neste request: o push não identifica o aparelho. */
    fun notificationReceived(data: Dito.NotificationReadData) {
        scope.launch {
            if (data.userId.isEmpty()) return@launch
            // O ingest descarta em silêncio um Receipt sem notification_id.
            if (data.notificationId.isEmpty()) {
                Log.w("Tracker", "Entrega sem notification id descartada.")
                return@launch
            }
            val identifyActivity = mapper.mapIdentify(Identify(data.userId))
            val trackEvent = Event(PUSH_RECEIVE_EVENT).apply {
                this.data = CustomData().apply {
                    params["dispatch_id"] = data.logId
                    params["notification_id"] = data.notificationId
                    params["notification_name"] = data.notificationName
                }
            }
            val activityId = UUID.randomUUID().toString()
            val receipt = mapper.mapPushReceipt(data.notificationId, data.logId, data.notificationName, data.userId, activityId)
            try {
                client.activity(mapper.buildRequest(data.userId, listOf(identifyActivity, receipt), null))
            } catch (e: Exception) {
                // Sem isto, uma entrega perdida era indistinguível de uma entrega bem-sucedida: sem
                // log, sem fila, sem rastro. `createdAt` do evento já está preenchido, então o
                // reenvio preserva o instante real da entrega, não o do retry.
                Log.e("Tracker", "Falha ao enviar a entrega da notificação ${data.notificationId}.", e)
                // Push do aparelho anônimo volta pelo caminho anônimo (user_id vazio + identify anônimo).
                if (data.userId.equals(anonymousUserId(), ignoreCase = true)) {
                    trackerOffline.event(trackEvent, activityId, anonymous = true)
                } else {
                    trackerOffline.event(trackEvent, activityId, userId = data.userId)
                }
            }
        }
    }

    // Mesmo user_id que o backend deriva do device_id para o aparelho anônimo.
    internal fun anonymousUserId(): String? {
        if (mapper.deviceId.isEmpty()) return null
        val digest = MessageDigest.getInstance("SHA-1").digest(mapper.deviceId.trim().lowercase().toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }

    /**
     * @param data Custom data extra do clique (ex.: `action_id`/`action_label` de um botão).
     *   Persistido junto do clique na fila offline, então a atribuição de qual botão foi tocado
     *   sobrevive ao reenvio.
     */
    fun notificationClick(
        notificationId: String,
        notificationReference: String,
        userId: String,
        data: Map<String, String> = emptyMap(),
        logId: String = "",
        notificationName: String = "",
    ) {
        scope.launch {
            if (userId.isEmpty() || notificationId.isEmpty()) return@launch
            val activityId = UUID.randomUUID().toString()
            val activity = mapper.mapNotificationClick(notificationId, userId, activityId, data, logId, notificationName)
            try {
                client.activity(mapper.buildRequest(userId, listOf(activity), null))
            } catch (e: Exception) {
                Log.e("Tracker", "Falha ao enviar o clique da notificação $notificationId; enfileirado para retry.", e)
                trackerOffline.notificationRead(activityId, notificationId, userId, data, logId, notificationName)
            }
        }
    }
}
