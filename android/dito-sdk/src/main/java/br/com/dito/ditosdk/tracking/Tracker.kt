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

    lateinit var id: String
    private var trackerRetry: TrackerRetry? = null

    init {
        loadIdentify()
    }

    val idOrNull: String? get() = if (::id.isInitialized) id else null

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

    fun identify(identify: Identify, callback: (() -> Unit)?) {
        scope.launch {
            if (debug) Log.d("Tracker", "begin identify user: ${identify.id}")
            id = identify.id
            val activity = mapper.mapIdentify(identify)
            val request = mapper.buildRequest(id, listOf(activity), null)
            try {
                client.activity(request)
                trackerOffline.identify(identify, send = true)
                callback?.invoke()
                trackerRetry?.uploadEvents()
            } catch (e: Exception) {
                if (debug) Log.d("Tracker", "identify error: ${e.message}")
                trackerOffline.identify(identify, send = false)
            }
        }
    }

    fun event(event: Event) {
        scope.launch {
            val activityId = UUID.randomUUID().toString()
            if (!::id.isInitialized) {
                Log.e("Tracker", "Antes de enviar um evento é preciso identificar o usuário.")
                trackerOffline.event(event, activityId)
                return@launch
            }
            val activity = mapper.mapTrack(event, activityId)
            val request = mapper.buildRequest(id, listOf(activity), null)
            try {
                client.activity(request)
            } catch (e: Exception) {
                handleEventError(e, event, activityId)
            }
        }
    }

    private fun handleEventError(exception: Exception, event: Event, activityId: String) {
        if (exception is UninitializedPropertyAccessException) {
            Log.e("Tracker", "Antes de enviar um evento é preciso identificar o usuário.")
        }
        trackerOffline.event(event, activityId)
    }

    fun registerToken(token: String) {
        scope.launch {
            try {
                if (!::id.isInitialized) {
                    Log.e("Tracker", "Antes de registrar o token é preciso identificar o usuário.")
                    return@launch
                }
                val activity = mapper.mapTokenRegister(token)
                val request = mapper.buildRequest(id, listOf(activity), token)
                client.activity(request)
            } catch (e: Exception) {
                if (debug) Log.d("Tracker", "registerToken error: ${e.message}")
            }
        }
    }

    fun unregisterToken(token: String) {
        scope.launch {
            try {
                if (!::id.isInitialized) {
                    Log.e("Tracker", "Antes de registrar o token é preciso identificar o usuário.")
                    return@launch
                }
                val activity = mapper.mapTokenUnregister(token)
                val request = mapper.buildRequest(id, listOf(activity), token)
                client.activity(request)
            } catch (e: Exception) {
                Log.e("Tracker", e.message, e)
            }
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









