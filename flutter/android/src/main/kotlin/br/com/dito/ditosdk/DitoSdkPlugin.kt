package br.com.dito.ditosdk

import android.content.Context
import com.google.firebase.messaging.RemoteMessage
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class DitoSdkPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var notificationEventsChannel: EventChannel
    private var context: Context? = null
    private var debugEnabled: Boolean = false

    companion object {
        private const val NOTIFICATION_EVENTS_CHANNEL = "br.com.dito/notification_events"
        private const val NOTIFICATION_CLICK_EVENT = "notification_click"

        @Volatile
        private var ditoInitialized: Boolean = false

        @Volatile
        private var notificationEventSink: EventChannel.EventSink? = null

        @JvmStatic
        fun handleNotification(context: Context, message: RemoteMessage): Boolean {
            if (!isDitoChannel(message)) {
                return false
            }
            ensureDitoInitialized(context)
            processNotificationData(message)
            return true
        }

        @JvmStatic
        private fun isDitoChannel(message: RemoteMessage): Boolean {
            val channel = message.data["channel"]
            return channel == "DITO" || channel == "Dito"
        }

        @JvmStatic
        private fun ensureDitoInitialized(context: Context) {
            if (!ditoInitialized) {
                try {
                    Dito.init(context, null)
                    ditoInitialized = true
                } catch (e: RuntimeException) {
                    android.util.Log.w("DitoSdkPlugin", "Dito SDK not initialized: ${e.message}")
                }
            }
        }

        @JvmStatic
        private fun processNotificationData(message: RemoteMessage) {
            val data = message.data["data"] ?: return
            try {
                val notificationData = parseNotificationData(data)
                if (isValidNotificationData(notificationData)) {
                    sendNotificationRead(notificationData)
                }
            } catch (e: Exception) {
                android.util.Log.e("DitoSdkPlugin", "Error processing notification: ${e.message}")
            }
        }

        @JvmStatic
        private fun parseNotificationData(data: String): NotificationData {
            val jsonData = org.json.JSONObject(data)
            val notificationId = jsonData.optString("notification", "")
            val reference = jsonData.optString("reference", "")
            val logId = jsonData.optString("log_id", "")
            val notificationName = jsonData.optString("notification_name", "")
            val userId = jsonData.optString("user_id", "")
            return NotificationData(notificationId, reference, logId, notificationName, userId)
        }

        @JvmStatic
        private fun isValidNotificationData(data: NotificationData): Boolean {
            return data.notificationId.isNotEmpty() && data.reference.isNotEmpty()
        }

        @JvmStatic
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

        private data class NotificationData(
            val notificationId: String,
            val reference: String,
            val logId: String,
            val notificationName: String,
            val userId: String
        )

        @JvmStatic
        fun handleNotificationClick(context: Context, userInfo: Map<String, String>): Boolean {
            val channel = userInfo["channel"]
            if (!channel.equals("DITO", ignoreCase = true)) {
                return false
            }
            ensureDitoInitialized(context)
            val normalizedUserInfo = normalizeClickUserInfo(userInfo)
            Dito.notificationClick(normalizedUserInfo) { deeplink ->
                emitNotificationClickEvent(deeplink, normalizedUserInfo)
            }
            return true
        }

        @JvmStatic
        private fun normalizeClickUserInfo(userInfo: Map<String, String>): Map<String, String> {
            val deeplink = userInfo["deeplink"] ?: userInfo["link"] ?: ""
            return userInfo.toMutableMap().apply {
                putIfAbsent("deeplink", deeplink)
            }
        }

        @JvmStatic
        private fun emitNotificationClickEvent(deeplink: String, userInfo: Map<String, String>) {
            val payload: MutableMap<String, Any?> = HashMap()
            payload["type"] = NOTIFICATION_CLICK_EVENT
            payload["deeplink"] = deeplink
            payload["notificationId"] = userInfo["notification"] ?: ""
            payload["reference"] = userInfo["reference"] ?: ""
            payload["logId"] = userInfo["log_id"] ?: ""
            payload["notificationName"] = userInfo["notification_name"] ?: ""
            payload["userId"] = userInfo["user_id"] ?: ""
            notificationEventSink?.success(payload)
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "br.com.dito/dito_sdk")
        channel.setMethodCallHandler(this)
        notificationEventsChannel =
            EventChannel(flutterPluginBinding.binaryMessenger, NOTIFICATION_EVENTS_CHANNEL)
        notificationEventsChannel.setStreamHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "setDebugMode" -> {
                val enabled = call.argument<Boolean>("enabled")
                if (enabled == null) {
                    result.error(
                        "INVALID_PARAMETERS",
                        "enabled is required and cannot be null",
                        null
                    )
                    return
                }
                debugEnabled = enabled
                Dito.options = Options().apply { debug = enabled }
                result.success(null)
            }
            "initialize" -> {
                val appKey = call.argument<String>("appKey")
                val appSecret = call.argument<String>("appSecret")

                if (appKey.isNullOrEmpty() || appSecret.isNullOrEmpty()) {
                    result.error(
                        "INVALID_CREDENTIALS",
                        "appKey and appSecret are required and cannot be empty",
                        null
                    )
                    return
                }

                try {
                    val ctx = context
                    if (ctx == null) {
                        result.error(
                            "INITIALIZATION_FAILED",
                            "Context is not available",
                            null
                        )
                        return
                    }

                    try {
                        val options = Options().apply { debug = debugEnabled }
                        Dito.init(ctx, appKey, appSecret, options)
                        ditoInitialized = true
                        result.success(null)
                    } catch (e: RuntimeException) {
                        if (e.message?.contains("API_KEY e API_SECRET no AndroidManifest") == true) {
                            result.error(
                                "INITIALIZATION_FAILED",
                                "Dito SDK requires API_KEY and API_SECRET to be configured in AndroidManifest.xml. Please add them to your app's AndroidManifest.xml file.",
                                null
                            )
                        } else {
                            throw e
                        }
                    }
                } catch (e: Exception) {
                    result.error(
                        "INITIALIZATION_FAILED",
                        "Failed to initialize Dito SDK: ${e.message}",
                        null
                    )
                }
            }
            "identify" -> {
                val id = call.argument<String>("id")
                val name = call.argument<String>("name")
                val email = call.argument<String>("email")
                val customData = call.argument<Map<String, Any>>("customData")

                if (id.isNullOrEmpty()) {
                    result.error(
                        "INVALID_PARAMETERS",
                        "id is required and cannot be empty",
                        null
                    )
                    return
                }

                try {
                    Dito.identify(
                        id = id,
                        name = name,
                        email = email,
                        customData = customData
                    )
                    result.success(null)
                } catch (e: Exception) {
                    result.error(
                        "NETWORK_ERROR",
                        "Failed to identify user: ${e.message}",
                        null
                    )
                }
            }
            "track" -> {
                val action = call.argument<String>("action")
                val data = call.argument<Map<String, Any>>("data")

                if (action.isNullOrEmpty()) {
                    result.error(
                        "INVALID_PARAMETERS",
                        "action is required and cannot be empty",
                        null
                    )
                    return
                }

                try {
                    Dito.track(
                        action = action,
                        data = data
                    )
                    result.success(null)
                } catch (e: Exception) {
                    result.error(
                        "NETWORK_ERROR",
                        "Failed to track event: ${e.message}",
                        null
                    )
                }
            }
            "registerDeviceToken" -> {
                val token = call.argument<String>("token")

                if (token.isNullOrEmpty()) {
                    result.error(
                        "INVALID_PARAMETERS",
                        "token is required and cannot be empty",
                        null
                    )
                    return
                }

                try {
                    Dito.registerDevice(token)
                    result.success(null)
                } catch (e: Exception) {
                    result.error(
                        "NETWORK_ERROR",
                        "Failed to register device token: ${e.message}",
                        null
                    )
                }
            }
            "unregisterDeviceToken" -> {
                val token = call.argument<String>("token")

                if (token.isNullOrEmpty()) {
                    result.error(
                        "INVALID_PARAMETERS",
                        "token is required and cannot be empty",
                        null
                    )
                    return
                }

                try {
                    Dito.unregisterDevice(token)
                    result.success(null)
                } catch (e: Exception) {
                    result.error(
                        "NETWORK_ERROR",
                        "Failed to unregister device token: ${e.message}",
                        null
                    )
                }
            }
            "handleNotificationClick" -> {
                val ctx = context
                if (ctx == null) {
                    result.success(false)
                    return
                }
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    result.success(false)
                    return
                }

                val userInfo: MutableMap<String, String> = HashMap()
                for ((key, value) in args) {
                    if (key == null) continue
                    userInfo[key.toString()] = value?.toString() ?: ""
                }
                result.success(handleNotificationClick(ctx, userInfo))
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        notificationEventSink = events
    }

    override fun onCancel(arguments: Any?) {
        notificationEventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        notificationEventsChannel.setStreamHandler(null)
        notificationEventSink = null
        context = null
    }
}
