package com.example.dito_sdk

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import br.com.dito.ditosdk.Dito
import com.google.firebase.messaging.RemoteMessage

class DitoSdkPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: Context? = null

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
            return NotificationData(notificationId, reference)
        }

        @JvmStatic
        private fun isValidNotificationData(data: NotificationData): Boolean {
            return data.notificationId.isNotEmpty() && data.reference.isNotEmpty()
        }

        @JvmStatic
        private fun sendNotificationRead(data: NotificationData) {
            val userInfo = mapOf(
                "notification" to data.notificationId,
                "reference" to data.reference
            )
            Dito.notificationRead(userInfo)
        }

        private data class NotificationData(
            val notificationId: String,
            val reference: String
        )

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
            "initialize" -> {
                val apiKey = call.argument<String>("apiKey")
                val apiSecret = call.argument<String>("apiSecret")

                if (apiKey.isNullOrEmpty() || apiSecret.isNullOrEmpty()) {
                    result.error(
                        "INVALID_CREDENTIALS",
                        "apiKey and apiSecret are required and cannot be empty",
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
                        Dito.init(ctx, null)
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
