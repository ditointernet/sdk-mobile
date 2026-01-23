package br.com.dito.ditosdk

import android.content.Context
import android.content.pm.PackageManager
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
    fun init(context: Context?, options: Options?) {
        this.options = options

        val appInfo = context?.packageManager?.getApplicationInfo(
            context.packageName,
            PackageManager.GET_META_DATA
        )

        appInfo?.metaData?.let {
            apiKey = it.getString("br.com.dito.API_KEY", "")
            apiSecret = it.getString("br.com.dito.API_SECRET", "")
            hibridMode = it.getString("br.com.dito.HIBRID_MODE", "OFF")

            if (apiKey.isEmpty() || apiSecret.isEmpty()) {
                throw RuntimeException("É preciso configurar API_KEY e API_SECRET no AndroidManifest.")
            }

            val trackerOffline = TrackerOffline(context)

            tracker = Tracker(apiKey, apiSecret, trackerOffline)

            val trackerRetry = TrackerRetry(tracker, trackerOffline, options?.retry ?: 5)
            tracker.setTrackerRetry(trackerRetry)
            trackerRetry.uploadEvents()
        }
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
        identify(identifyObject, null)
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
    fun notificationRead(userInfo: Map<String, String>) {
        val notificationData = extractNotificationReadData(userInfo)
        processNotificationRead(notificationData)
    }

    private fun extractNotificationReadData(userInfo: Map<String, String>): NotificationReadData {
        val notificationId = userInfo["notification"] ?: ""
        val reference = userInfo["reference"] ?: ""
        val logId = userInfo["log_id"] ?: ""
        val notificationName = userInfo["notification_name"] ?: ""
        val userId = userInfo["user_id"] ?: ""
        return NotificationReadData(notificationId, reference, logId, notificationName, userId)
    }

    private fun processNotificationRead(data: NotificationReadData) {
        if (data.reference.isEmpty()) {
            return
        }
        if (data.notificationId.isEmpty()) {
            return
        }
        sendNotificationRead(data)
        identifyUserForNotification(data.userId)
        trackNotificationReceived(data)
    }

    private fun sendNotificationRead(data: NotificationReadData) {
        tracker.notificationRead(
            data.notificationId,
            RemoteService.notificationApi(),
            data.reference
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

    private data class NotificationReadData(
        val notificationId: String,
        val reference: String,
        val logId: String,
        val notificationName: String,
        val userId: String
    )

    /**
     * Called when a notification arrives (before click)
     * @param notification Notification ID
     * @param reference User reference
     * @deprecated Use notificationRead(userInfo:) instead for consistency with iOS SDK
     */
    @Deprecated(
        message = "Use notificationRead(userInfo:) instead for consistency with iOS SDK",
        replaceWith = ReplaceWith("notificationRead(mapOf(\"notification\" to (notification ?: \"\"), \"reference\" to (reference ?: \"\")))")
    )
    fun notificationRead(notification: String?, reference: String?) {
        if (reference.isNullOrEmpty() || notification.isNullOrEmpty()) {
            return
        }
        val userInfo = mapOf(
            "notification" to notification,
            "reference" to reference
        )
        notificationRead(userInfo)
    }

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
            notificationRead(data.notificationId, data.reference)
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
        return apiKey.isNotEmpty() && apiSecret.isNotEmpty()
    }

    fun getHibridMode(): String {
        return hibridMode;
    }

}
