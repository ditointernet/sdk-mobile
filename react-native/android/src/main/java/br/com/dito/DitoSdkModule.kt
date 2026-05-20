package br.com.dito

import android.content.Context
import br.com.dito.ditosdk.Dito
import br.com.dito.ditosdk.notification.DitoNotificationOptions
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.ReadableType
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class DitoSdkModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String {
        return "DitoSdkModule"
    }

    companion object {
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

        private fun isDitoChannel(message: RemoteMessage): Boolean {
            val channel = message.data["channel"]
            return channel == "Dito"
        }

        private fun ensureInitialized(context: Context) {
            if (!Dito.isInitialized()) {
                Dito.init(context, null)
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
            val channel = userInfo["channel"]
            if (channel != "Dito") {
                return false
            }
            ensureInitialized(context)
            Dito.notificationClick(userInfo)
            return true
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

            Dito.initWithApiKey(context, apiKey, bundleId, null)
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
