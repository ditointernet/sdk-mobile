package br.com.dito.ditosdk

import br.com.dito.ditosdk.notification.DitoRichPushParser
import br.com.dito.ditosdk.tracking.Tracker

internal object DitoNotificationHandler {

    private const val ACTION_ID_KEY = "action_id"
    private const val ACTION_LABEL_KEY = "action_label"

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

    /**
     * Custom data extra que vai junto do evento `click-notification`. Só é preenchida quando o
     * clique veio de um botão — o clique no corpo continua enviando um mapa vazio, mantendo o
     * payload idêntico ao que já era emitido.
     */
    fun extractClickData(userInfo: Map<String, String>): Map<String, String> {
        val actionId = userInfo[ACTION_ID_KEY].orEmpty()
        if (actionId.isEmpty()) return emptyMap()
        val data = LinkedHashMap<String, String>()
        data[ACTION_ID_KEY] = actionId
        userInfo[ACTION_LABEL_KEY]?.takeIf { it.isNotEmpty() }?.let { data[ACTION_LABEL_KEY] = it }
        return data
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
        val clickData = extractClickData(userInfo)
        if (notificationId != null && reference != null) {
            tracker.notificationClick(notificationId, reference, userId, clickData)
        }
        callback?.invoke(deepLink)
        return NotificationResult(
            notificationId = notificationId ?: "",
            reference = reference ?: "",
            deepLink = deepLink,
            actionId = userInfo[ACTION_ID_KEY].orEmpty(),
            actionLabel = userInfo[ACTION_LABEL_KEY].orEmpty(),
            customData = DitoRichPushParser.parseCustomData(userInfo["custom_data"]),
        )
    }
}
