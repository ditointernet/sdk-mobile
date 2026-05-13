package br.com.dito.ditosdk

import br.com.dito.ditosdk.tracking.Tracker

internal object DitoNotificationHandler {

    fun extractReadData(userInfo: Map<String, String>): Dito.NotificationReadData =
        Dito.NotificationReadData(
            notificationId = userInfo["notification"] ?: "",
            reference = userInfo["reference"] ?: "",
            logId = userInfo["log_id"] ?: "",
            notificationName = userInfo["notification_name"] ?: "",
            userId = userInfo["user_id"] ?: "",
        )

    fun processReceived(data: Dito.NotificationReadData, tracker: Tracker) {
        tracker.notificationReceived(data)
    }

    fun handleClick(
        userInfo: Map<String, String>,
        callback: ((String) -> Unit)?,
        tracker: Tracker,
    ): NotificationResult {
        val notificationId = userInfo["notification"]
        val reference = userInfo["reference"]
        val deepLink = userInfo["deeplink"] ?: ""
        val userId = userInfo["user_id"] ?: ""
        if (notificationId != null && reference != null) {
            tracker.notificationClick(notificationId, reference, userId)
        }
        callback?.invoke(deepLink)
        return NotificationResult(
            notificationId = notificationId ?: "",
            reference = reference ?: "",
            deepLink = deepLink,
        )
    }
}
