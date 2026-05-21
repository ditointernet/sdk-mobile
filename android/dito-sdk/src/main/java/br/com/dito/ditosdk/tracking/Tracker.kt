package br.com.dito.ditosdk.tracking

import android.util.Log
import br.com.dito.ditosdk.CustomData
import br.com.dito.ditosdk.Dito
import br.com.dito.ditosdk.Event
import br.com.dito.ditosdk.Identify
import br.com.dito.ditosdk.service.ActivityMapper
import br.com.dito.ditosdk.service.MobileIngestClientInterface
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.util.UUID

internal class Tracker(
    private val trackerOffline: TrackerOffline,
    private val client: MobileIngestClientInterface,
    private val mapper: ActivityMapper,
    private val debug: Boolean = false,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
) {

    var id: String? = null
    private var trackerRetry: TrackerRetry? = null

    init {
        loadIdentify()
    }

    val idOrNull: String? get() = id

    fun setTrackerRetry(retry: TrackerRetry) {
        this.trackerRetry = retry
    }

    fun close() {
        trackerRetry?.close()
        scope.cancel()
    }

    private fun loadIdentify() {
        scope.launch {
            trackerOffline.getIdentify()?.let { id = it.id }
        }
    }

    enum class OperationStatus {
        SENT,
        SAVED_LOCALLY,
    }

    fun identify(identify: Identify, callback: ((OperationStatus?, Throwable?) -> Unit)?) {
        scope.launch {
            if (debug) Log.d("Tracker", "begin identify user: ${identify.id}")
            id = identify.id
            val activity = mapper.mapIdentify(identify)
            val request = mapper.buildRequest(identify.id, listOf(activity), null)
            try {
                client.activity(request)
                trackerOffline.identify(identify, send = true)
                callback?.invoke(OperationStatus.SENT, null)
                trackerRetry?.uploadEvents()
            } catch (e: Exception) {
                if (debug) Log.d("Tracker", "identify error: $e", e)
                trackerOffline.identify(identify, send = false)
                callback?.invoke(null, e)
            }
        }
    }

    fun event(event: Event, callback: ((OperationStatus?, Throwable?) -> Unit)? = null) {
        scope.launch {
            val activityId = UUID.randomUUID().toString()
            val userId = id
            if (userId == null) {
                Log.e("Tracker", "Antes de enviar um evento é preciso identificar o usuário.")
                trackerOffline.event(event, activityId)
                callback?.invoke(OperationStatus.SAVED_LOCALLY, null)
                return@launch
            }
            val activity = mapper.mapTrack(event, activityId)
            val request = mapper.buildRequest(userId, listOf(activity), null)
            try {
                client.activity(request)
                callback?.invoke(OperationStatus.SENT, null)
            } catch (e: Exception) {
                handleEventError(e, event, activityId)
                callback?.invoke(OperationStatus.SAVED_LOCALLY, null)
            }
        }
    }

    private fun handleEventError(exception: Exception, event: Event, activityId: String) {
        if (exception is UninitializedPropertyAccessException) {
            Log.e("Tracker", "Antes de enviar um evento é preciso identificar o usuário.")
        }
        trackerOffline.event(event, activityId)
    }

    fun registerToken(token: String, callback: ((OperationStatus?, Throwable?) -> Unit)? = null) {
        scope.launch {
            try {
                val userId = id
                if (userId == null) {
                    val error = IllegalStateException("Antes de registrar o token é preciso identificar o usuário.")
                    Log.e("Tracker", error.message ?: "")
                    callback?.invoke(null, error)
                    return@launch
                }
                val activity = mapper.mapTokenRegister(token)
                val request = mapper.buildRequest(userId, listOf(activity), token)
                client.activity(request)
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
                val userId = id
                if (userId == null) {
                    val error = IllegalStateException("Antes de remover o token é preciso identificar o usuário.")
                    Log.e("Tracker", error.message ?: "")
                    callback?.invoke(null, error)
                    return@launch
                }
                val activity = mapper.mapTokenUnregister(token)
                val request = mapper.buildRequest(userId, listOf(activity), token)
                client.activity(request)
                callback?.invoke(OperationStatus.SENT, null)
            } catch (e: Exception) {
                Log.e("Tracker", e.message, e)
                callback?.invoke(null, e)
            }
        }
    }

    fun logout() {
        id = null
        scope.launch {
            trackerOffline.deleteIdentify()
        }
    }

    fun notificationReceived(data: Dito.NotificationReadData) {
        scope.launch {
            if (data.userId.isEmpty()) return@launch
            id = data.userId
            val identifyActivity = mapper.mapIdentify(Identify(data.userId))
            val trackEvent = Event("receive-android-notification").apply {
                this.data = CustomData().apply {
                    params["dispatch_id"] = data.logId
                    params["notification_id"] = data.notificationId
                    params["notification_name"] = data.notificationName
                }
            }
            val trackActivity = mapper.mapTrack(trackEvent)
            val request = mapper.buildRequest(data.userId, listOf(identifyActivity, trackActivity), null)
            try {
                client.activity(request)
            } catch (_: Exception) { }
        }
    }

    fun notificationClick(notificationId: String, notificationReference: String, userId: String) {
        scope.launch {
            if (userId.isEmpty() || notificationId.isEmpty()) return@launch
            val activityId = UUID.randomUUID().toString()
            val activity = mapper.mapNotificationClick(notificationId, userId, activityId)
            val request = mapper.buildRequest(userId, listOf(activity), null)
            try {
                client.activity(request)
            } catch (_: Exception) {
                trackerOffline.notificationRead(activityId, notificationId, userId)
            }
        }
    }
}



