package br.com.dito.ditosdk.tracking

import android.util.Log
import br.com.dito.ditosdk.EventOff
import br.com.dito.ditosdk.NotificationReadOff
import br.com.dito.ditosdk.service.RemoteService
import com.google.gson.JsonObject
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

internal class TrackerRetry(
    private var tracker: Tracker,
    private var trackerOffline: TrackerOffline,
    private var retry: Int = 5,
    private val loginApi: br.com.dito.ditosdk.service.LoginApi = RemoteService.loginApi(),
    private val eventApi: br.com.dito.ditosdk.service.EventApi = RemoteService.eventApi(),
    private val notificationApi: br.com.dito.ditosdk.service.NotificationApi = RemoteService.notificationApi(),
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
) {

    private val gson = br.com.dito.ditosdk.service.utils.gson()

    fun uploadEvents() {
        checkIdentify()
        checkEvent()
        checkNotificationRead()
    }

    private fun checkIdentify() {
        scope.launch {
            val identifyOff = trackerOffline.getIdentify()
            identifyOff?.let {
                if (!it.send) {
                    val value = gson.fromJson(it.json, JsonObject::class.java)
                    try {
                        val response = loginApi.signup("portal", identifyOff.id, value)
                        if (response.isSuccessful) {
                            val reference =
                                response.body()?.getAsJsonObject("data")?.get("reference")?.asString
                            reference?.let {
                                trackerOffline.updateIdentify(identifyOff.id, true)
                            }
                        }
                    } catch (e: Exception) {
                        Log.d("tracker", "tracker retry: error checking identify")
                    }
                }
            }
        }
    }

    private fun checkEvent() {
        scope.launch {
            val events = trackerOffline.getAllEvents()
            events?.forEach {
                try {
                    if (it.retry == retry) {
                        trackerOffline.delete(it.id, "Event")
                    } else {
                        sendEvent(it, tracker.id)
                    }
                } catch (e: Exception) {
                    if (e is UninitializedPropertyAccessException) {
                        Log.e(
                            "Tracker",
                            "Antes de enviar um evento é preciso identificar o usuário."
                        )
                    }
                }
            }
        }
    }

    private suspend fun sendEvent(eventOff: EventOff, id: String) {
        try {
            val params = gson.fromJson(eventOff.json, JsonObject::class.java)
            val response = eventApi.track(id, params)
            if (!response.isSuccessful) {
                trackerOffline.update(eventOff.id, (eventOff.retry + 1), "Event")
            } else {
                trackerOffline.delete(eventOff.id, "Event")
            }
        } catch (e: Exception) {
            trackerOffline.update(eventOff.id, (eventOff.retry + 1), "Event")
        }
    }


    private fun checkNotificationRead() {
        scope.launch {
            val notifications = trackerOffline.getAllNotificationRead()
            notifications?.forEach {
                try {
                    if (it.retry == retry) {
                        trackerOffline.delete(it.id, "NotificationRead")
                    } else {
                        sendNotificationRead(it, tracker.id)
                    }
                } catch (e: Exception) {
                    if (e is UninitializedPropertyAccessException) {
                        Log.e(
                            "Tracker",
                            "Antes de enviar um evento é preciso identificar o usuário."
                        )
                    }
                }
            }
        }
    }

    private suspend fun sendNotificationRead(notificationReadOff: NotificationReadOff, id: String) {
        try {
            val params = gson.fromJson(notificationReadOff.json, JsonObject::class.java)
            val response = notificationApi.open(id, params)
            if (!response.isSuccessful) {
                trackerOffline.update(
                    notificationReadOff.id,
                    (notificationReadOff.retry + 1),
                    "NotificationRead"
                )
            } else {
                trackerOffline.delete(notificationReadOff.id, "NotificationRead")
            }
        } catch (e: Exception) {
            trackerOffline.update(
                notificationReadOff.id,
                (notificationReadOff.retry + 1),
                "NotificationRead"
            )
        }
    }


}
