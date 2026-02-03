package br.com.dito.ditosdk

import android.content.Context
import br.com.dito.ditosdk.Dito
import com.google.firebase.messaging.RemoteMessage
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class DitoSdkPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var debugEnabled: Boolean = false

    companion object {
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
            return channel == "Dito"
        }

        @JvmStatic
        private fun ensureDitoInitialized(context: Context) {
            if (!Dito.isInitialized()) {
                Dito.init(context, null)
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
            if (channel != "Dito") {
                return false
            }
            ensureDitoInitialized(context)
            Dito.notificationClick(userInfo)
            return true
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "br.com.dito/dito_sdk")
        channel.setMethodCallHandler(this)
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
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }
}
