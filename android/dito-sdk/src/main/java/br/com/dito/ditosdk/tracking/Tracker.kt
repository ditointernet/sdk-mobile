package br.com.dito.ditosdk.tracking

import android.util.Log
import br.com.dito.ditosdk.Event
import br.com.dito.ditosdk.Identify
import br.com.dito.ditosdk.service.EventApi
import br.com.dito.ditosdk.service.LoginApi
import br.com.dito.ditosdk.service.NotificationApi
import br.com.dito.ditosdk.service.utils.EventRequest
import br.com.dito.ditosdk.service.utils.NotificationOpenRequest
import br.com.dito.ditosdk.service.utils.SigunpRequest
import br.com.dito.ditosdk.service.utils.TokenRequest
import br.com.dito.ditosdk.utils.DitoSDKUtils
import com.google.gson.JsonObject
import kotlinx.coroutines.*
import retrofit2.Response

internal class Tracker(private var apiKey: String, apiSecret: String, private var trackerOffline: TrackerOffline) {

    private var apiSecret: String = DitoSDKUtils.SHA1(apiSecret)

    lateinit var id: String
    lateinit var reference: String
    private var trackerRetry: TrackerRetry? = null

    init {
        loadIdentify()
    }

    fun setTrackerRetry(retry: TrackerRetry) {
        this.trackerRetry = retry
    }

    @OptIn(DelicateCoroutinesApi::class)
    private fun loadIdentify() {
        GlobalScope.launch(Dispatchers.IO) {
            val identify = trackerOffline.getIdentify()
            identify?.let {
                id = it.id
                reference = it.reference.orEmpty()
            }
        }
    }

    @OptIn(DelicateCoroutinesApi::class)
    fun identify(identify: Identify, api: LoginApi, callback: (() -> Unit)?) {
        GlobalScope.launch(Dispatchers.IO) {
            Log.d("begin-identify", "begin identify user")
            id = identify.id
            val params = SigunpRequest(apiKey, apiSecret, identify)
            try {
                val response = api.signup("portal", identify.id, params)
                handleIdentifyResponse(response, params, callback)
            } catch (e: Exception) {
                Log.d("error-identify", e.message.toString())
                trackerOffline.identify(params, null, false)
            }
        }
    }

    private fun handleIdentifyResponse(
        response: Response<JsonObject>,
        params: SigunpRequest,
        callback: (() -> Unit)?
    ) {
        if (!response.isSuccessful) {
            trackerOffline.identify(params, null, false)
            return
        }
        val body = response.body() ?: return
        reference = body.getAsJsonObject("data").get("reference").asString
        trackerOffline.identify(params, reference, true)
        callback?.invoke()
        trackerRetry?.uploadEvents()
    }

    @OptIn(DelicateCoroutinesApi::class)
    fun event(event: Event, api: EventApi) {
        GlobalScope.launch(Dispatchers.IO) {
            val params = EventRequest(apiKey, apiSecret, event)
            if (!::id.isInitialized) {
                Log.e("Tracker", "Antes de enviar um evento é preciso identificar o usuário.")
                trackerOffline.event(params)
                return@launch
            }
            try {
                val response = api.track(id, params)
                if (!response.isSuccessful) {
                    trackerOffline.event(params)
                }
            } catch (e: Exception) {
                handleEventError(e, params)
            }
        }
    }

    private fun handleEventError(exception: Exception, params: EventRequest) {
        if (exception is UninitializedPropertyAccessException) {
            Log.e("Tracker", "Antes de enviar um evento é preciso identificar o usuário.")
        }
        trackerOffline.event(params)
    }

    @OptIn(DelicateCoroutinesApi::class)
    fun registerToken(token: String, api: NotificationApi) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                val params = TokenRequest(apiKey, apiSecret, token)
                val response = api.add(id, params)
                if (!response.isSuccessful) {
                    Log.d("Tracker", response.errorBody().toString())
                }
            } catch (e: Exception) {
                handleRegisterTokenError(e)
            }
        }
    }

    private fun handleRegisterTokenError(exception: Exception) {
        if (exception is UninitializedPropertyAccessException) {
            Log.e("Tracker", "Antes de registrar o token é preciso identificar o usuário.")
        }
    }

    @OptIn(DelicateCoroutinesApi::class)
    fun unregisterToken(token: String, api: NotificationApi) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                val params = TokenRequest(apiKey, apiSecret, token)
                val response = api.disable(id, params)
                if (!response.isSuccessful) {
                    Log.d("Tracker", response.errorBody().toString())
                }
            } catch (e: Exception) {
                Log.e("Tracker", e.message, e)
            }
        }
    }

    @OptIn(DelicateCoroutinesApi::class)
    fun notificationClick(notificationId: String, api: NotificationApi, notificationReference: String) {
        GlobalScope.launch(Dispatchers.IO) {
            if (notificationReference.isEmpty() || notificationId.isEmpty()) {
                return@launch
            }

            val data = createNotificationData(notificationReference)
            val params = NotificationOpenRequest(apiKey, apiSecret, data)

            sendNotificationClick(notificationId, api, params)
        }
    }

    private fun createNotificationData(notificationReference: String): JsonObject {
        val data = JsonObject()
        data.addProperty("identifier", notificationReference.substring(5))
        data.addProperty("reference", notificationReference)
        return data
    }

    private suspend fun sendNotificationClick(
        notificationId: String,
        api: NotificationApi,
        params: NotificationOpenRequest
    ) {
        try {
            val response = api.open(notificationId, params)
            if (!response.isSuccessful) {
                trackerOffline.notificationRead(params)
            }
        } catch (e: Exception) {
            trackerOffline.notificationRead(params)
        }
    }
}
