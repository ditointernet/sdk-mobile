package br.com.dito.ditosdk

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.RequiresApi
import br.com.dito.ditosdk.service.RemoteService
import br.com.dito.ditosdk.tracking.Tracker
import br.com.dito.ditosdk.tracking.TrackerOffline
import br.com.dito.ditosdk.tracking.TrackerRetry

object Dito {

    private lateinit var apiKey: String
    private lateinit var hibridMode: String
    private lateinit var apiSecret: String
    private lateinit var tracker: Tracker

    const val DITO_NOTIFICATION_ID = "br.com.dito.ditosdk.DITO_NOTIFICATION_ID"
    const val DITO_NOTIFICATION_REFERENCE = "br.com.dito.ditosdk.DITO_NOTIFICATION_REFERENCE"
    const val DITO_DEEP_LINK = "br.com.dito.ditosdk.DITO_DEEP_LINK"

    var options: Options? = null

    /**
     *
     * @param context
     * @param options
     */
    @RequiresApi(Build.VERSION_CODES.O)
    fun init(context: Context?, options: Options?) {
        this.options = options

        val appInfo = context?.packageManager?.getApplicationInfo(
            context.packageName,
            PackageManager.GET_META_DATA
        )

        appInfo?.metaData?.let {
            val resolvedApiKey = it.getString("br.com.dito.API_KEY", "")
            val resolvedApiSecret = it.getString("br.com.dito.API_SECRET", "")
            val resolvedHibridMode = it.getString("br.com.dito.HIBRID_MODE", "OFF")
            configureTracker(context, options, resolvedApiKey, resolvedApiSecret, resolvedHibridMode)
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    fun init(
        context: Context?,
        apiKey: String,
        apiSecret: String,
        options: Options?
    ) {
        this.options = options
        val resolvedHibridMode = resolveHibridMode(context)
        if (context == null) {
            throw RuntimeException("Context is not available")
        }
        configureTracker(context, options, apiKey, apiSecret, resolvedHibridMode)
    }

    private fun resolveHibridMode(context: Context?): String {
        val appInfo = context?.packageManager?.getApplicationInfo(
            context.packageName,
            PackageManager.GET_META_DATA
        )
        return appInfo?.metaData?.getString("br.com.dito.HIBRID_MODE", "OFF") ?: "OFF"
    }

    private fun configureTracker(
        context: Context,
        options: Options?,
        apiKey: String,
        apiSecret: String,
        hibridMode: String
    ) {
        this.apiKey = apiKey
        this.apiSecret = apiSecret
        this.hibridMode = hibridMode

        if (apiKey.isEmpty() || apiSecret.isEmpty()) {
            throw RuntimeException("É preciso configurar API_KEY e API_SECRET no AndroidManifest.")
        }

        val trackerOffline = TrackerOffline(context)
        tracker = Tracker(apiKey, apiSecret, trackerOffline)

        val trackerRetry = TrackerRetry(tracker, trackerOffline, options?.retry ?: 5)
        tracker.setTrackerRetry(trackerRetry)
        trackerRetry.uploadEvents()
    }

    /**
     * Identifies a user in Dito CRM with individual parameters
     * @param id Unique user identifier
     * @param name User's name (optional)
     * @param email User's email (optional)
     * @param customData Additional custom data as map (optional)
     */
    fun identify(
        id: String,
        name: String? = null,
        email: String? = null,
        customData: Map<String, Any>? = null
    ) {
        val identifyObject = createIdentifyObject(id, name, email, customData)
        tracker.identify(identifyObject, RemoteService.loginApi(), null)
    }

    private fun createIdentifyObject(
        id: String,
        name: String?,
        email: String?,
        customData: Map<String, Any>?
    ): Identify {
        return Identify(id).apply {
            this.name = name
            this.email = email
            this.data = convertCustomData(customData)
        }
    }

    private fun convertCustomData(customData: Map<String, Any>?): CustomData? {
        if (customData == null) return null
        return CustomData().apply {
            customData.forEach { (key, value) ->
                addCustomDataValue(key, value)
            }
        }
    }

    private fun CustomData.addCustomDataValue(key: String, value: Any) {
        when (value) {
            is String -> add(key, value)
            is Int -> add(key, value)
            is Double -> add(key, value)
            is Boolean -> add(key, value)
            else -> params[key] = value
        }
    }

    /**
     * Identifies a user in Dito CRM with Identify object
     * @param identify Identify object with user data
     * @param callback Optional callback executed after identification
     * @deprecated Use identify(id:name:email:customData:) instead for consistency with iOS SDK
     */
    @Deprecated(
        message = "Use identify(id:name:email:customData:) instead for consistency with iOS SDK",
        replaceWith = ReplaceWith("identify(id, identify.name, identify.email, identify.data?.toMap())")
    )
    fun identify(identify: Identify?, callback: (() -> Unit)?) {
        identify?.let { tracker.identify(it, RemoteService.loginApi(), callback) }
    }

    /**
     * Tracks an event in Dito CRM with individual parameters
     * @param action Event action name
     * @param data Additional event data as map (optional)
     */
    fun track(
        action: String,
        data: Map<String, Any>? = null
    ) {
        val customData = convertCustomData(data)
        val event = Event(action).apply {
            this.data = customData
        }
        track(event)
    }

    /**
     * Tracks an event in Dito CRM with Event object
     * @param event Event object with event data
     * @deprecated Use track(action:data:) instead for consistency with iOS SDK
     */
    @Deprecated(
        message = "Use track(action:data:) instead for consistency with iOS SDK",
        replaceWith = ReplaceWith("track(event.action, event.data?.toMap())")
    )
    fun track(event: Event?) {
        event?.let { tracker.event(it, RemoteService.eventApi()) }
    }

    /**
     * Registers a device token for push notifications.
     * @param token Device token string (required, cannot be null or empty)
     */
    fun registerDevice(token: String?) {
        if (token.isNullOrEmpty()) {
            return
        }
        performRegisterDevice(token)
    }

    private fun performRegisterDevice(token: String) {
        tracker.registerToken(token, RemoteService.notificationApi())
    }

    /**
     * Unregisters a device token for push notifications.
     * @param token Device token string (required, cannot be null or empty)
     */
    fun unregisterDevice(token: String?) {
        if (token.isNullOrEmpty()) {
            return
        }
        performUnregisterDevice(token)
    }

    private fun performUnregisterDevice(token: String) {
        tracker.unregisterToken(token, RemoteService.notificationApi())
    }

    /**
     * Called when a notification arrives (before click)
     * @param userInfo Map containing notification data (should contain "notification" and "reference" keys)
     */
    fun notificationClick(userInfo: Map<String, String>) {
        val notificationData = extractNotificationReadData(userInfo)

        if (notificationData.reference.isEmpty()) {
            return
        }
        if (notificationData.notificationId.isEmpty()) {
            return
        }

        sendNotificationClick(notificationData.notificationId, notificationData.reference)
    }

    fun notificationRead(userInfo: Map<String, String>) {
        val notificationData = extractNotificationReadData(userInfo)
        if (notificationData.reference.isEmpty()) {
            return
        }
        if (notificationData.notificationId.isEmpty()) {
            return
        }
        processNotificationReceived(notificationData)
    }

    private fun extractNotificationReadData(userInfo: Map<String, String>): NotificationReadData {
        val notificationId = userInfo["notification"] ?: ""
        val reference = userInfo["reference"] ?: ""
        val logId = userInfo["log_id"] ?: ""
        val notificationName = userInfo["notification_name"] ?: ""
        val userId = userInfo["user_id"] ?: ""
        return NotificationReadData(notificationId, reference, logId, notificationName, userId)
    }

    fun processNotificationReceived(data: NotificationReadData) {
        identifyUserForNotification(data.userId)
        trackNotificationReceived(data)
    }

    private fun sendNotificationClick(notificationId: String, userId: String) {
        tracker.notificationClick(
            notificationId,
            RemoteService.notificationApi(),
            userId
        )
    }

    private fun identifyUserForNotification(userId: String) {
        if (userId.isNotEmpty()) {
            identify(id = userId, name = null, email = null, customData = null)
        }
    }

    private fun trackNotificationReceived(data: NotificationReadData) {
        val trackData = createNotificationTrackData(data)
        track(action = "receive-android-notification", data = trackData)
    }

    private fun createNotificationTrackData(data: NotificationReadData): Map<String, Any> {
        return mapOf(
            "canal" to "mobile",
            "id-disparo" to data.logId,
            "id-notificacao" to data.notificationId,
            "nome_notificacao" to data.notificationName,
            "provedor" to "firebase",
            "sistema_operacional" to "Android"
        )
    }

    data class NotificationReadData(
        val notificationId: String,
        val reference: String,
        val logId: String,
        val notificationName: String,
        val userId: String
    )

    /**
     * Called when a notification is clicked
     * @param userInfo Map containing notification data (should contain "notification", "reference", and "deeplink" keys)
     * @param callback Optional callback executed with deeplink
     * @return NotificationResult object with notification data
     */
    fun notificationClick(
        userInfo: Map<String, String>,
        callback: ((String) -> Unit)? = null
    ): NotificationResult {
        val notificationData = extractNotificationData(userInfo)
        processNotificationClick(notificationData)
        invokeCallback(callback, notificationData.deepLink)
        return createNotificationResult(notificationData)
    }

    private data class NotificationData(
        val notificationId: String?,
        val reference: String?,
        val deepLink: String
    )

    private fun extractNotificationData(userInfo: Map<String, String>): NotificationData {
        val notificationId = userInfo["notification"]
        val reference = userInfo["reference"]
        val deepLink = userInfo["deeplink"] ?: ""
        return NotificationData(notificationId, reference, deepLink)
    }

    private fun processNotificationClick(data: NotificationData) {
        if (data.notificationId != null && data.reference != null) {
            sendNotificationClick(data.notificationId, data.reference)
        }
    }

    private fun invokeCallback(callback: ((String) -> Unit)?, deepLink: String) {
        callback?.invoke(deepLink)
    }

    private fun createNotificationResult(data: NotificationData): NotificationResult {
        return NotificationResult(
            notificationId = data.notificationId ?: "",
            reference = data.reference ?: "",
            deepLink = data.deepLink
        )
    }

    internal fun isInitialized(): Boolean {
        return ::apiKey.isInitialized &&
            ::apiSecret.isInitialized &&
            apiKey.isNotEmpty() &&
            apiSecret.isNotEmpty()
    }

    fun getHibridMode(): String {
        return hibridMode;
    }

}
