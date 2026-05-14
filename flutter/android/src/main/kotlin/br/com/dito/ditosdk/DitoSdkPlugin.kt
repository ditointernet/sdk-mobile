package br.com.dito.ditosdk

import android.content.Context
import android.os.Handler
import android.os.Looper
import br.com.dito.ditosdk.notification.DitoNotificationOptions
import com.google.firebase.messaging.RemoteMessage
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class DitoSdkPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var notificationEventsChannel: EventChannel
    private var context: Context? = null
    private var debugEnabled: Boolean = false
    internal var logoutHandler: () -> Unit = { Dito.logout() }

    companion object {
        private const val NOTIFICATION_EVENTS_CHANNEL = "br.com.dito/notification_events"
        private const val NOTIFICATION_CLICK_EVENT = "notification_click"
        private const val CLICK_DEDUPE_WINDOW_MS = 1_500L

        @Volatile
        private var ditoInitialized: Boolean = false

        @Volatile
        private var notificationEventSink: EventChannel.EventSink? = null

        @Volatile
        private var lastClickKey: String? = null

        @Volatile
        private var lastClickAt: Long = 0

        @JvmStatic
        fun handleNotification(context: Context, message: RemoteMessage): Boolean {
            return DitoMessagingServiceHelper.handleMessage(context, message)
        }

        @JvmStatic
        fun handleNotificationClick(context: Context, userInfo: Map<String, String>): Boolean {
            val normalizedUserInfo = normalizeClickUserInfo(userInfo)
            val channel = normalizedUserInfo["channel"]
            if (!channel.equals("DITO", ignoreCase = true)) {
                return false
            }
            ensureDitoInitialized(context)
            if (isDuplicateClick(normalizedUserInfo)) {
                return true
            }
            Dito.notificationClick(normalizedUserInfo) { deeplink ->
                emitNotificationClickEvent(deeplink, normalizedUserInfo)
            }
            return true
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

        private fun normalizeClickUserInfo(userInfo: Map<String, String>): Map<String, String> {
            val normalizedUserInfo = userInfo.toMutableMap()
            val rawData = userInfo["data"]
            if (!rawData.isNullOrBlank()) {
                try {
                    val jsonData = org.json.JSONObject(rawData)
                    jsonData.keys().forEach { key ->
                        normalizedUserInfo[key] = jsonData.optString(key, "")
                    }
                } catch (e: Exception) {
                    android.util.Log.w("DitoSdkPlugin", "Invalid notification data payload: ${e.message}")
                }
            }
            val deeplink = normalizedUserInfo["deeplink"] ?: normalizedUserInfo["link"] ?: ""
            normalizedUserInfo["deeplink"] = deeplink
            return normalizedUserInfo
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
            val duplicate = key == lastClickKey && now - lastClickAt < CLICK_DEDUPE_WINDOW_MS
            lastClickKey = key
            lastClickAt = now
            return duplicate
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
            "initializeWithApiKey" -> {
                val apiKey = call.argument<String>("apiKey")
                val bundleId = call.argument<String>("bundleId")
                if (apiKey.isNullOrEmpty() || bundleId.isNullOrEmpty()) {
                    result.error(
                        "INVALID_CREDENTIALS",
                        "apiKey and bundleId are required and cannot be empty",
                        null
                    )
                    return
                }
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
                    Dito.initWithApiKey(ctx, apiKey, bundleId, Options().apply { debug = debugEnabled })
                    ditoInitialized = true
                    result.success(null)
                } catch (e: Exception) {
                    result.error(
                        "INITIALIZATION_FAILED",
                        "Failed to initialize Dito SDK: ${e.message}",
                        null
                    )
                }
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
                    ) { status, error ->
                        completeOperationResult(
                            result,
                            status,
                            error,
                            "NETWORK_ERROR",
                            "Failed to identify user"
                        )
                    }
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
                    ) { status, error ->
                        completeOperationResult(
                            result,
                            status,
                            error,
                            "NETWORK_ERROR",
                            "Failed to track event"
                        )
                    }
                } catch (e: Exception) {
                    result.error(
                        "NETWORK_ERROR",
                        "Failed to track event: ${e.message}",
                        null
                    )
                }
            }
            "logout" -> {
                logoutHandler()
                result.success(null)
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
                    Dito.registerDevice(token) { status, error ->
                        completeOperationResult(
                            result,
                            status,
                            error,
                            "NETWORK_ERROR",
                            "Failed to register device token"
                        )
                    }
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
                    Dito.unregisterDevice(token) { status, error ->
                        completeOperationResult(
                            result,
                            status,
                            error,
                            "NETWORK_ERROR",
                            "Failed to unregister device token"
                        )
                    }
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
            "setNotificationOptions" -> {
                val args = call.arguments as? Map<*, *> ?: run {
                    result.success(null)
                    return
                }
                val options = DitoNotificationOptions(
                    smallIconResId = (args["smallIconResId"] as? Number)?.toInt(),
                    largeIconResId = (args["largeIconResId"] as? Number)?.toInt(),
                    soundResourceName = args["soundResourceName"] as? String,
                    accentColor = (args["accentColor"] as? Number)?.toInt()
                )
                Dito.setNotificationOptions(options)
                result.success(null)
            }
            "getNotifications" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        val records = Dito.getNotifications()
                        val maps = records.map { info ->
                            mapOf(
                                "id" to info.id,
                                "notificationId" to info.notificationId,
                                "reference" to info.reference,
                                "title" to info.title,
                                "message" to info.message,
                                "link" to info.link,
                                "receivedAt" to info.receivedAt,
                                "isRead" to info.isRead
                            )
                        }
                        Handler(Looper.getMainLooper()).post { result.success(maps) }
                    } catch (e: Exception) {
                        Handler(Looper.getMainLooper()).post { result.error("INBOX_ERROR", e.message, null) }
                    }
                }
            }
            "markNotificationAsRead" -> {
                val args = call.arguments as? Map<*, *>
                val id = args?.get("id") as? String
                if (id == null) {
                    result.error("INBOX_ERROR", "id argument missing", null)
                    return
                }
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        Dito.markNotificationAsRead(id)
                        Handler(Looper.getMainLooper()).post { result.success(null) }
                    } catch (e: Exception) {
                        Handler(Looper.getMainLooper()).post { result.error("INBOX_ERROR", e.message, null) }
                    }
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        notificationEventSink = events
    }

    private fun completeOperationResult(
        result: Result,
        status: DitoOperationStatus?,
        error: Throwable?,
        errorCode: String,
        errorPrefix: String
    ) {
        Handler(Looper.getMainLooper()).post {
            if (error != null) {
                result.error(
                    errorCode,
                    "$errorPrefix: ${error.message}",
                    null
                )
                return@post
            }
            if (status == null) {
                result.error(
                    "INVALID_OPERATION_RESULT",
                    "$errorPrefix: native operation completed without status",
                    null
                )
                return@post
            }
            result.success(operationStatusMap(requireOperationStatus(status)))
        }
    }

    internal fun requireOperationStatus(status: DitoOperationStatus?): DitoOperationStatus =
        requireNotNull(status) { "Native operation completed without status" }

    internal fun operationStatusMap(status: DitoOperationStatus): Map<String, String> {
        val rawStatus = when (status) {
            DitoOperationStatus.SENT -> "sent"
            DitoOperationStatus.SAVED_LOCALLY -> "saved_locally"
        }
        return mapOf("status" to rawStatus)
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
