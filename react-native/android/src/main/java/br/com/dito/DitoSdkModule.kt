package br.com.dito

import android.content.Context
import android.os.Handler
import android.os.Looper
import br.com.dito.ditosdk.Dito
import br.com.dito.ditosdk.NotificationResult
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.ReadableType
import com.facebook.react.bridge.WritableArray
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class DitoSdkModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    init {
        // O caminho estático (`handleNotification*`, chamado do app host) precisa alcançar a
        // bridge para emitir, e não tem instância em mãos.
        reactContextRef = reactContext
        // O clique pode chegar antes de qualquer chamada que passe por ensureInitialized.
        installClickDataListener()
    }

    override fun getName(): String {
        return "DitoSdkModule"
    }

    override fun invalidate() {
        listenerCount = 0
        reactContextRef = null
        super.invalidate()
    }

    companion object {
        /** Nome do evento no `RCTDeviceEventEmitter`; espelha `NOTIFICATION_CLICK_EVENT` no TS. */
        private const val NOTIFICATION_CLICK_EVENT = "dito_notification_click"

        @Volatile
        private var reactContextRef: ReactApplicationContext? = null

        /**
         * Quantos listeners de JavaScript estão ativos.
         *
         * Decide para onde o clique vai: com listener ativo ele é emitido; sem listener ele
         * fica em [pendingInitialClick] até o app pedir por `getInitialNotificationClick`.
         * Assim o clique é entregue exatamente uma vez, nunca duas.
         */
        @Volatile
        private var listenerCount: Int = 0

        @Volatile
        private var clickDataListenerInstalled: Boolean = false

        /**
         * userInfo do clique que está sendo processado neste exato momento.
         *
         * [NotificationResult] não carrega `log_id`, `notification_name` nem `user_id`, e o
         * evento em JavaScript expõe os três. Quando o clique entra por
         * [handleNotificationClick] o mapa completo está em mãos, então ele fica aqui para o
         * listener completar o evento. `Dito.notificationClick` invoca o listener de forma
         * síncrona, então não há janela para o valor vazar para outro clique.
         */
        @Volatile
        private var pendingClickUserInfo: Map<String, String>? = null

        /**
         * Clique que chegou sem ninguém do lado do JavaScript para receber.
         *
         * Guardado como mapa comum, e não como `WritableMap`: um `WritableMap` só pode ser
         * consumido uma vez, e este payload pode ser convertido no momento da entrega.
         *
         * Só o último clique é guardado — um cold start vem de um toque só.
         */
        @Volatile
        private var pendingInitialClick: Map<String, Any?>? = null

        /**
         * Registra o listener de clique da SDK nativa sem esperar pela bridge do React.
         *
         * Um toque em notificação faz cold start do app, e nesse caminho a SDK nativa pode
         * processar o clique antes de o módulo React existir — nesse caso o evento é perdido.
         * Chame isto do `onCreate` da sua `Application` para que o clique seja capturado e
         * fique disponível em `DitoSdk.getInitialNotificationClick()`.
         */
        @JvmStatic
        fun installNotificationClickListener(context: Context) {
            ensureInitialized(context)
        }

        /**
         * Handles a push notification and processes it if it belongs to Dito channel.
         *
         * This method should be called from your Firebase Messaging Service's onMessageReceived method.
         * It verifies if the notification belongs to the Dito channel (channel == "Dito") and processes it accordingly.
         *
         * @param context The application context
         * @param message The RemoteMessage received from Firebase
         * @return true if the notification was processed by Dito SDK, false otherwise
         */
        @JvmStatic
        fun handleNotification(context: Context, message: RemoteMessage): Boolean {
            if (!isDitoChannel(message)) {
                return false
            }
            ensureInitialized(context)
            processNotificationData(message.data["data"])
            return true
        }

        /**
         * O channel-senders emite `channel: "DITO"` em maiúsculas
         * (`channelDITO = "DITO"`), então a comparação exata com `"Dito"` que estava aqui
         * rejeitava **todo** push da Dito — não só o push rico. O plugin Flutter sempre
         * aceitou as duas formas; esta é a mesma regra, agora insensível a caixa.
         */
        private fun isDitoChannel(message: RemoteMessage): Boolean {
            return message.data["channel"].equals("DITO", ignoreCase = true)
        }

        /**
         * Se a SDK nativa já foi inicializada por este módulo.
         *
         * O que estava aqui era `Dito.isInitialized()`, que é `internal` na SDK e portanto
         * inacessível de outro módulo Gradle — este arquivo não compilava. A flag local é a
         * mesma solução que o plugin Flutter usa, e não obriga a alargar a API pública da SDK.
         */
        @Volatile
        private var ditoInitialized: Boolean = false

        private fun ensureInitialized(context: Context) {
            installClickDataListener()
            if (ditoInitialized) return
            try {
                Dito.init(context, null)
                ditoInitialized = true
            } catch (e: RuntimeException) {
                android.util.Log.w("DitoSdkModule", "Dito SDK not initialized: ${e.message}")
            }
        }

        /**
         * Encaminha para o JavaScript **todo** clique que a SDK nativa processa.
         *
         * Sem isto o JavaScript só veria os cliques que o próprio app entregasse por
         * [handleNotificationClick], e um toque em botão de ação nunca passa por lá: o
         * `PendingIntent` do botão vai para a `NotificationOpenedActivity` da SDK, então o
         * `onMessageOpenedApp` da biblioteca de Firebase do app não dispara. Este listener é
         * o único ponto por onde o clique no corpo e o clique no botão passam.
         *
         * Um listener já registrado pelo app host é preservado e chamado antes.
         */
        @JvmStatic
        private fun installClickDataListener() {
            if (clickDataListenerInstalled) return
            clickDataListenerInstalled = true
            val previous = Dito.notificationClickDataListener
            Dito.notificationClickDataListener = { result ->
                previous?.invoke(result)
                emitNotificationClickEvent(result, pendingClickUserInfo ?: emptyMap())
            }
        }

        private fun processNotificationData(data: String?) {
            if (data == null) return
            val notificationData = extractNotificationData(data)
            if (notificationData != null) {
                sendNotificationRead(notificationData)
            }
        }

        private data class NotificationData(
            val notificationId: String,
            val reference: String,
            val logId: String,
            val notificationName: String,
            val userId: String
        )

        private fun extractNotificationData(data: String): NotificationData? {
            return try {
                val jsonData = org.json.JSONObject(data)
                val notificationId = jsonData.optString("notification", "")
                val reference = jsonData.optString("reference", "")
                val logId = jsonData.optString("log_id", "")
                val notificationName = jsonData.optString("notification_name", "")
                val userId = jsonData.optString("user_id", "")
                if (notificationId.isNotEmpty() && reference.isNotEmpty()) {
                    NotificationData(notificationId, reference, logId, notificationName, userId)
                } else {
                    null
                }
            } catch (e: Exception) {
                android.util.Log.e("DitoSdkModule", "Error processing notification: ${e.message}")
                null
            }
        }

        private fun sendNotificationRead(data: NotificationData) {
            val userInfo = mapOf(
                "notification" to data.notificationId,
                "reference" to data.reference,
                "log_id" to data.logId,
                "notification_name" to data.notificationName,
                "user_id" to data.userId
            )
            Dito.notificationRead(userInfo)
        }

        /**
         * Handles a notification click/interaction and processes it if it belongs to Dito channel.
         *
         * This method should be called when a notification is clicked.
         * It verifies if the notification belongs to the Dito channel and processes the click accordingly.
         *
         * @param context The application context
         * @param userInfo Map containing notification data (should contain "notification", "reference", and "deeplink" keys)
         * @return true if the notification was processed by Dito SDK, false otherwise
         */
        @JvmStatic
        fun handleNotificationClick(context: Context, userInfo: Map<String, String>): Boolean {
            if (!userInfo["channel"].equals("DITO", ignoreCase = true)) {
                return false
            }
            ensureInitialized(context)
            val normalizedUserInfo = normalizeClickUserInfo(userInfo)
            // A sobrecarga de um argumento **não** invoca o `notificationClickDataListener`,
            // então com ela o JavaScript nunca seria avisado. A de dois argumentos invoca — o
            // `null` explícito desambigua as duas.
            //
            // O userInfo inteiro é repassado, então `action_id`, `action_label` e
            // `custom_data` — quando o caller os incluir — chegam ao SDK sem tradução.
            //
            // A emissão para o JavaScript acontece no listener, que cobre este caminho e o do
            // toque em botão. Emitir aqui também duplicaria o evento.
            pendingClickUserInfo = normalizedUserInfo
            try {
                Dito.notificationClick(normalizedUserInfo, null)
            } finally {
                pendingClickUserInfo = null
            }
            return true
        }

        /**
         * Garante a chave `deeplink`, que é a única que a SDK lê.
         *
         * O payload do FCM traz o destino em `link`, então um caller que repasse o data map
         * cru ficaria com o deeplink vazio.
         */
        @JvmStatic
        private fun normalizeClickUserInfo(userInfo: Map<String, String>): Map<String, String> {
            val deeplink = userInfo["deeplink"] ?: userInfo["link"] ?: ""
            return userInfo.toMutableMap().apply {
                putIfAbsent("deeplink", deeplink)
            }
        }

        /**
         * Monta o evento a partir do [NotificationResult] e o entrega, ou o guarda.
         *
         * [userInfo] é o mapa cru do clique quando ele veio de [handleNotificationClick], e
         * serve só para completar os campos que o [NotificationResult] não carrega. Quando o
         * clique nasce na notificação nativa esses três campos vêm vazios — o `PendingIntent`
         * não transporta `log_id`/`notification_name`. Antes desta mudança o evento nem
         * existia nesse caminho, então não há regressão.
         */
        @JvmStatic
        private fun emitNotificationClickEvent(
            result: NotificationResult,
            userInfo: Map<String, String>,
        ) {
            val payload = HashMap<String, Any?>()
            payload["deeplink"] = result.deepLink
            payload["notificationId"] = result.notificationId
            payload["reference"] = result.reference
            payload["logId"] = userInfo["log_id"] ?: ""
            payload["notificationName"] = userInfo["notification_name"] ?: ""
            payload["userId"] = userInfo["user_id"] ?: ""
            payload["actionId"] = result.actionId
            payload["actionLabel"] = result.actionLabel
            payload["customData"] = result.customData

            if (!deliverClickToJs(payload)) {
                pendingInitialClick = payload
            }
        }

        @JvmStatic
        private fun deliverClickToJs(payload: Map<String, Any?>): Boolean {
            if (listenerCount <= 0) return false
            val context = reactContextRef ?: return false
            if (!context.hasActiveReactInstance()) return false
            return try {
                context
                    .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
                    .emit(NOTIFICATION_CLICK_EVENT, toWritableMap(payload))
                true
            } catch (e: Exception) {
                android.util.Log.w("DitoSdkModule", "Could not emit notification click: ${e.message}")
                false
            }
        }

        /**
         * Devolve o clique guardado e o descarta, para que ele seja entregue uma única vez.
         */
        @JvmStatic
        private fun takePendingInitialClick(): Map<String, Any?>? = synchronized(this) {
            val pending = pendingInitialClick
            pendingInitialClick = null
            pending
        }

        @JvmStatic
        private fun toWritableMap(payload: Map<String, Any?>): WritableMap {
            val map = Arguments.createMap()
            for ((key, value) in payload) {
                when (value) {
                    null -> map.putNull(key)
                    is String -> map.putString(key, value)
                    is Boolean -> map.putBoolean(key, value)
                    is Int -> map.putInt(key, value)
                    // A bridge do React só tem `double`. Epoch em milissegundos cabe exato
                    // num double até 2^53, então `receivedAt` não perde precisão.
                    is Long -> map.putDouble(key, value.toDouble())
                    is Double -> map.putDouble(key, value)
                    is Map<*, *> -> map.putMap(key, toWritableStringMap(value))
                    else -> map.putString(key, value.toString())
                }
            }
            return map
        }

        @JvmStatic
        private fun toWritableStringMap(source: Map<*, *>): WritableMap {
            val map = Arguments.createMap()
            for ((key, value) in source) {
                if (key == null) continue
                map.putString(key.toString(), value?.toString() ?: "")
            }
            return map
        }
    }

    @ReactMethod
    fun initialize(apiKey: String, apiSecret: String, promise: Promise) {
        try {
            if (apiKey.isEmpty() || apiSecret.isEmpty()) {
                promise.reject(
                    "INVALID_CREDENTIALS",
                    "apiKey and apiSecret are required and cannot be empty",
                    null
                )
                return
            }

            val context: Context? = reactApplicationContext.applicationContext
            if (context == null) {
                promise.reject(
                    "INITIALIZATION_FAILED",
                    "Context is not available",
                    null
                )
                return
            }

            try {
                Dito.init(context, apiKey, apiSecret, null)
                ditoInitialized = true
                promise.resolve(null)
            } catch (e: RuntimeException) {
                if (e.message?.contains("API_KEY e API_SECRET no AndroidManifest") == true) {
                    promise.reject(
                        "INITIALIZATION_FAILED",
                        "Dito SDK requires API_KEY and API_SECRET to be configured in AndroidManifest.xml. Please add them to your app's AndroidManifest.xml file.",
                        e
                    )
                } else {
                    promise.reject(
                        "INITIALIZATION_FAILED",
                        "Failed to initialize Dito SDK: ${e.message}",
                        e
                    )
                }
            }
        } catch (e: Exception) {
            promise.reject(
                "INITIALIZATION_FAILED",
                "Failed to initialize Dito SDK: ${e.message}",
                e
            )
        }
    }

    @ReactMethod
    fun identify(
        id: String,
        name: String?,
        email: String?,
        customData: ReadableMap?,
        promise: Promise
    ) {
        try {
            if (id.isEmpty()) {
                promise.reject(
                    "INVALID_PARAMETERS",
                    "id is required and cannot be empty",
                    null
                )
                return
            }

            val customDataMap = readableMapToMap(customData)

            Dito.identify(
                id = id,
                name = name,
                email = email,
                customData = customDataMap
            )
            promise.resolve(null)
        } catch (e: Exception) {
            promise.reject(
                "NETWORK_ERROR",
                "Failed to identify user: ${e.message}",
                e
            )
        }
    }

    @ReactMethod
    fun track(action: String, data: ReadableMap?, promise: Promise) {
        try {
            if (action.isEmpty()) {
                promise.reject(
                    "INVALID_PARAMETERS",
                    "action is required and cannot be empty",
                    null
                )
                return
            }

            val dataMap = readableMapToMap(data)

            Dito.track(
                action = action,
                data = dataMap
            )
            promise.resolve(null)
        } catch (e: Exception) {
            promise.reject(
                "NETWORK_ERROR",
                "Failed to track event: ${e.message}",
                e
            )
        }
    }

    @ReactMethod
    fun registerDeviceToken(token: String, promise: Promise) {
        try {
            if (token.isEmpty()) {
                promise.reject(
                    "INVALID_PARAMETERS",
                    "token is required and cannot be empty",
                    null
                )
                return
            }

            Dito.registerDevice(token)
            promise.resolve(null)
        } catch (e: Exception) {
            promise.reject(
                "NETWORK_ERROR",
                "Failed to register device token: ${e.message}",
                e
            )
        }
    }

    @ReactMethod
    fun unregisterDeviceToken(token: String, promise: Promise) {
        try {
            if (token.isEmpty()) {
                promise.reject(
                    "INVALID_PARAMETERS",
                    "token is required and cannot be empty",
                    null
                )
                return
            }

            Dito.unregisterDevice(token)
            promise.resolve(null)
        } catch (e: Exception) {
            promise.reject(
                "NETWORK_ERROR",
                "Failed to unregister device token: ${e.message}",
                e
            )
        }
    }

    /**
     * Chamados pelo `NativeEventEmitter` do React a cada `addListener`/`remove` em JavaScript.
     *
     * Servem só para contar: é a contagem que decide se o clique é emitido na hora ou fica
     * guardado para o `getInitialNotificationClick`. O nome do evento é ignorado de
     * propósito — este módulo emite um evento só, e `removeListeners` não recebe nome, então
     * filtrar só na entrada faria a contagem derivar.
     *
     * Sem os dois métodos declarados aqui o `NativeEventEmitter` nem guarda referência ao
     * módulo nativo, e a contagem nunca chegaria.
     */
    @ReactMethod
    fun addListener(eventName: String) {
        listenerCount += 1
    }

    @ReactMethod
    fun removeListeners(count: Double) {
        listenerCount = (listenerCount - count.toInt()).coerceAtLeast(0)
    }

    @ReactMethod
    fun getInitialNotificationClick(promise: Promise) {
        val pending = takePendingInitialClick()
        promise.resolve(pending?.let { toWritableMap(it) })
    }

    @ReactMethod
    fun getNotifications(promise: Promise) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val records = Dito.getNotifications()
                val array: WritableArray = Arguments.createArray()
                records.forEach { info ->
                    array.pushMap(
                        toWritableMap(
                            mapOf(
                                "id" to info.id,
                                "notificationId" to info.notificationId,
                                "reference" to info.reference,
                                "title" to info.title,
                                "message" to info.message,
                                "link" to info.link,
                                "receivedAt" to info.receivedAt,
                                "isRead" to info.isRead,
                                "image" to info.image,
                                "customData" to info.customData
                            )
                        )
                    )
                }
                Handler(Looper.getMainLooper()).post { promise.resolve(array) }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    promise.reject("INBOX_ERROR", e.message, e)
                }
            }
        }
    }

    @ReactMethod
    fun markNotificationAsRead(id: String, promise: Promise) {
        if (id.isEmpty()) {
            promise.reject("INVALID_PARAMETERS", "id is required and cannot be empty", null)
            return
        }
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Dito.markNotificationAsRead(id)
                Handler(Looper.getMainLooper()).post { promise.resolve(null) }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    promise.reject("INBOX_ERROR", e.message, e)
                }
            }
        }
    }

    private fun readableMapToMap(map: ReadableMap?): Map<String, Any>? {
        if (map == null) {
            return null
        }
        val result = mutableMapOf<String, Any>()
        val iterator = map.keySetIterator()
        while (iterator.hasNextKey()) {
            val key = iterator.nextKey()
            when (map.getType(key)) {
                ReadableType.Null -> Unit
                ReadableType.Boolean -> result[key] = map.getBoolean(key)
                ReadableType.Number -> result[key] = map.getDouble(key)
                ReadableType.String -> result[key] = map.getString(key) ?: ""
                ReadableType.Map -> {
                    val nested = readableMapToMap(map.getMap(key))
                    if (nested != null) {
                        result[key] = nested
                    }
                }
                ReadableType.Array -> {
                    val list = readableArrayToList(map.getArray(key))
                    if (list != null) {
                        result[key] = list
                    }
                }
            }
        }
        return result
    }

    private fun readableArrayToList(array: ReadableArray?): List<Any>? {
        if (array == null) {
            return null
        }
        val result = mutableListOf<Any>()
        for (index in 0 until array.size()) {
            when (array.getType(index)) {
                ReadableType.Null -> Unit
                ReadableType.Boolean -> result.add(array.getBoolean(index))
                ReadableType.Number -> result.add(array.getDouble(index))
                ReadableType.String -> result.add(array.getString(index) ?: "")
                ReadableType.Map -> {
                    val nested = readableMapToMap(array.getMap(index))
                    if (nested != null) {
                        result.add(nested)
                    }
                }
                ReadableType.Array -> {
                    val list = readableArrayToList(array.getArray(index))
                    if (list != null) {
                        result.add(list)
                    }
                }
            }
        }
        return result
    }
}
