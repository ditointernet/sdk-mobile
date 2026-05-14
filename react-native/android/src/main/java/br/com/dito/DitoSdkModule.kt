package br.com.dito

import android.content.Context
import br.com.dito.ditosdk.Dito
import br.com.dito.ditosdk.notification.DitoNotificationHandler
import br.com.dito.ditosdk.notification.DitoNotificationOptions
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.ReadableType
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject

class DitoSdkModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    init {
        currentReactContext = reactContext
    }

    override fun getName(): String {
        return "DitoSdkModule"
    }

    companion object {
        private const val NOTIFICATION_CLICK_EVENT = "DitoNotificationClick"

        @Volatile
        private var currentReactContext: ReactApplicationContext? = null

        @Volatile
        private var lastClickKey: String? = null

        @Volatile
        private var lastClickAt: Long = 0

        @JvmStatic
        fun handleNotification(context: Context, message: RemoteMessage): Boolean {
            val normalizedMessage = normalizeRemoteMessage(message)
            val handler = DitoNotificationHandler(context)
            if (!handler.canHandle(normalizedMessage)) {
                return false
            }
            handler.handleNotification(normalizedMessage)
            return true
        }

        private fun normalizeRemoteMessage(message: RemoteMessage): RemoteMessage {
            val normalizedData = normalizeNotificationData(message.data)
            return RemoteMessage.Builder("dito").setData(normalizedData).build()
        }

        private fun normalizeNotificationData(userInfo: Map<String, String>): Map<String, String> {
            val normalizedUserInfo = userInfo.toMutableMap()
            val rawData = userInfo["data"]
            if (!rawData.isNullOrBlank()) {
                try {
                    val jsonData = JSONObject(rawData)
                    jsonData.keys().forEach { key ->
                        normalizedUserInfo[key] = jsonData.optString(key, "")
                    }
                } catch (e: Exception) {
                    android.util.Log.w("DitoSdkModule", "Invalid notification data payload: ${e.message}")
                }
            }

            normalizedUserInfo["channel"] = normalizedUserInfo["channel"]?.uppercase().orEmpty()

            val link = normalizedUserInfo["link"]
            val deeplink = normalizedUserInfo["deeplink"]
            if (link.isNullOrEmpty() && !deeplink.isNullOrEmpty()) {
                normalizedUserInfo["link"] = deeplink
            }
            if (deeplink.isNullOrEmpty() && !link.isNullOrEmpty()) {
                normalizedUserInfo["deeplink"] = link
            }

            return normalizedUserInfo
        }

        @JvmStatic
        fun handleNotificationClick(context: Context, userInfo: Map<String, String>): Boolean {
            val normalizedUserInfo = normalizeClickUserInfo(userInfo)
            val channel = normalizedUserInfo["channel"]
            if (!channel.equals("DITO", ignoreCase = true)) {
                return false
            }
            ensureInitialized(context)
            if (isDuplicateClick(normalizedUserInfo)) {
                return true
            }
            Dito.notificationClick(normalizedUserInfo) { deeplink ->
                emitNotificationClickEvent(deeplink, normalizedUserInfo)
            }
            return true
        }

        private fun ensureInitialized(context: Context) {
            if (!Dito.isInitialized()) {
                Dito.init(context, null)
            }
        }

        private fun normalizeClickUserInfo(userInfo: Map<String, String>): Map<String, String> {
            return normalizeNotificationData(userInfo)
        }

        @Synchronized
        private fun isDuplicateClick(userInfo: Map<String, String>): Boolean {
            val key = listOf(
                userInfo["notification"].orEmpty(),
                userInfo["reference"].orEmpty(),
                userInfo["log_id"].orEmpty(),
                userInfo["deeplink"].orEmpty()
            ).joinToString("|")
            val now = System.currentTimeMillis()
            val duplicate = key == lastClickKey && now - lastClickAt < 1500
            lastClickKey = key
            lastClickAt = now
            return duplicate
        }

        private fun emitNotificationClickEvent(deeplink: String, userInfo: Map<String, String>) {
            currentReactContext
                ?.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
                ?.emit(NOTIFICATION_CLICK_EVENT, createNotificationClickPayload(deeplink, userInfo))
        }

        private fun createNotificationClickPayload(deeplink: String, userInfo: Map<String, String>): WritableMap {
            val payload = Arguments.createMap()
            payload.putString("deeplink", deeplink)
            payload.putString("notificationId", userInfo["notification"] ?: "")
            payload.putString("reference", userInfo["reference"] ?: "")
            payload.putString("logId", userInfo["log_id"] ?: "")
            payload.putString("notificationName", userInfo["notification_name"] ?: "")
            payload.putString("userId", userInfo["user_id"] ?: "")
            return payload
        }
    }

    @ReactMethod
    fun initializeWithApiKey(apiKey: String, bundleId: String, promise: Promise) {
        try {
            if (apiKey.isEmpty() || bundleId.isEmpty()) {
                promise.reject(
                    "INVALID_CREDENTIALS",
                    "apiKey and bundleId are required and cannot be empty",
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

            Dito.init(context, apiKey, "", null)
            promise.resolve(null)
        } catch (e: Exception) {
            promise.reject(
                "INITIALIZATION_FAILED",
                "Failed to initialize Dito SDK: ${e.message}",
                e
            )
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
    fun logout(promise: Promise) {
        try {
            Dito.logout()
            promise.resolve(null)
        } catch (e: Exception) {
            promise.reject(
                "LOGOUT_FAILED",
                "Failed to logout: ${e.message}",
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
    fun setNotificationOptions(optionsMap: ReadableMap, promise: Promise) {
        try {
            val smallIconResId = if (optionsMap.hasKey("smallIconResId") && !optionsMap.isNull("smallIconResId")) optionsMap.getInt("smallIconResId") else null
            val largeIconResId = if (optionsMap.hasKey("largeIconResId") && !optionsMap.isNull("largeIconResId")) optionsMap.getInt("largeIconResId") else null
            val soundResourceName = if (optionsMap.hasKey("soundResourceName") && !optionsMap.isNull("soundResourceName")) optionsMap.getString("soundResourceName") else null
            val accentColor = if (optionsMap.hasKey("accentColor") && !optionsMap.isNull("accentColor")) optionsMap.getInt("accentColor") else null
            val options = DitoNotificationOptions(
                smallIconResId = smallIconResId,
                largeIconResId = largeIconResId,
                soundResourceName = soundResourceName,
                accentColor = accentColor
            )

            Dito.setNotificationOptions(options)
            promise.resolve(null)
        } catch (e: Exception) {
            promise.reject(
                "SET_NOTIFICATION_OPTIONS_FAILED",
                "Failed to set notification options: ${e.message}",
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

    @ReactMethod
    fun getNotifications(promise: Promise) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val records = Dito.getNotifications()
                val array = Arguments.createArray()
                for (info in records) {
                    val map = Arguments.createMap()
                    map.putString("id", info.id)
                    map.putString("notificationId", info.notificationId)
                    map.putString("reference", info.reference)
                    map.putString("title", info.title)
                    map.putString("message", info.message)
                    map.putString("link", info.link)
                    map.putDouble("receivedAt", info.receivedAt.toDouble())
                    map.putBoolean("isRead", info.isRead)
                    array.pushMap(map)
                }
                withContext(Dispatchers.Main) { promise.resolve(array) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) { promise.reject("INBOX_ERROR", e.message) }
            }
        }
    }

    @ReactMethod
    fun markNotificationAsRead(id: String, promise: Promise) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Dito.markNotificationAsRead(id)
                withContext(Dispatchers.Main) { promise.resolve(null) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) { promise.reject("INBOX_ERROR", e.message) }
            }
        }
    }

    @ReactMethod
    fun handleNotificationClick(userInfoMap: ReadableMap, promise: Promise) {
        val context = reactApplicationContext.applicationContext
        val userInfo = readableMapToStringMap(userInfoMap)
        promise.resolve(handleNotificationClick(context, userInfo))
    }

    @ReactMethod
    fun addListener(eventName: String) {
    }

    @ReactMethod
    fun removeListeners(count: Int) {
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

    private fun readableMapToStringMap(map: ReadableMap): Map<String, String> {
        val result = mutableMapOf<String, String>()
        val iterator = map.keySetIterator()
        while (iterator.hasNextKey()) {
            val key = iterator.nextKey()
            when (map.getType(key)) {
                ReadableType.Null -> result[key] = ""
                ReadableType.Boolean -> result[key] = map.getBoolean(key).toString()
                ReadableType.Number -> result[key] = map.getDouble(key).toString()
                ReadableType.String -> result[key] = map.getString(key) ?: ""
                ReadableType.Map -> {
                    val nested = readableMapToMap(map.getMap(key))
                    if (key == "data" && nested != null) {
                        result[key] = JSONObject(nested).toString()
                    }
                }
                ReadableType.Array -> Unit
            }
        }
        return result
    }

    override fun invalidate() {
        if (currentReactContext === reactApplicationContext) {
            currentReactContext = null
        }
        super.invalidate()
    }
}
