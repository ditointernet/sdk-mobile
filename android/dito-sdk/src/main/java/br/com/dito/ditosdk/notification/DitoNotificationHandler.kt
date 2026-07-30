package br.com.dito.ditosdk.notification

import android.content.Context
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import br.com.dito.ditosdk.Dito
import br.com.dito.ditosdk.Dito.NotificationReadData
import br.com.dito.ditosdk.notification.inbox.DitoNotificationRecord
import br.com.dito.ditosdk.offline.DitoDatabase
import com.google.firebase.messaging.RemoteMessage
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class DitoNotificationHandler(private val context: Context) {

    companion object {
        private const val TAG = "DitoNotificationHandler"
        private const val CHANNEL_KEY = "channel"
        private const val CHANNEL_VALUE = "DITO"

        /** Prefixo estável para grep do dump de payload (T9.1). */
        private const val PAYLOAD_LOG_PREFIX = "DITO_PUSH_PAYLOAD"
    }

    fun canHandle(remoteMessage: RemoteMessage): Boolean {
        val channel = remoteMessage.data[CHANNEL_KEY]
        val canHandle = remoteMessage.data.isNotEmpty() && channel == CHANNEL_VALUE

        return canHandle
    }

    @RequiresApi(Build.VERSION_CODES.O)
    fun handleNotification(remoteMessage: RemoteMessage) {
        if (!canHandle(remoteMessage)) {
            Log.w(TAG, "Attempted to handle non-DITO notification")
            return
        }

        logPayload(remoteMessage)

        val notificationId = remoteMessage.data["notification"] ?: ""
        val reference = remoteMessage.data["reference"] ?: ""
        val deepLink = remoteMessage.data["link"] ?: ""
        val title = remoteMessage.data["title"]?.takeIf { it.isNotEmpty() } ?: getApplicationName()
        val message = remoteMessage.data["message"] ?: ""
        val logId = remoteMessage.data["log_id"] ?: ""
        val notificationName = remoteMessage.data["notification_name"] ?: ""
        val userId = remoteMessage.data["user_id"] ?: ""

        // Campos ricos: aditivos e condicionais — só chegam quando a campanha usa o recurso.
        // `android.notification.image` é o fallback para brands que não estão em modo DATA.
        val imageUrl = remoteMessage.data["image"]?.takeIf { it.isNotBlank() }
            ?: remoteMessage.notification?.imageUrl?.toString()
        val customDataJson = remoteMessage.data["custom_data"]
        val actions = DitoRichPushParser.parseActions(remoteMessage.data["actions"])

        // Mesmo motivo do clique: só `notificationId` é obrigatório. Com `reference` na
        // condição, uma campanha sem o campo não registrava **nenhuma** entrega — a
        // notificação até aparecia na tela, porque `showNotification` está fora do gate,
        // e o evento simplesmente não existia.
        if (notificationId.isNotEmpty()) {
            try {
                if (!Dito.isInitialized()) {
                    Dito.init(context, null)
                }

                val notificationData = NotificationReadData(
                    notificationId,
                    reference,
                    logId,
                    notificationName,
                    userId
                )

                Dito.processNotificationReceived(notificationData)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to process notification received: ${e.message}")
            }
        }

        NotificationDisplayHelper.showNotification(
            context = context,
            title = title,
            message = message,
            notificationId = notificationId,
            reference = reference,
            deepLink = deepLink,
            channel = getApplicationName() + " notifications",
            channelDescription = getApplicationName() + " application notifications",
            userId = userId,
            options = Dito.notificationOptions,
            imageUrl = imageUrl,
            actions = actions,
            customDataJson = customDataJson,
        )

        val record = DitoNotificationRecord(
            id = UUID.randomUUID().toString(),
            notificationId = notificationId,
            reference = reference,
            title = title,
            message = message,
            link = deepLink,
            receivedAt = System.currentTimeMillis(),
            isRead = false,
            image = imageUrl ?: "",
            customData = customDataJson ?: "",
        )
        CoroutineScope(Dispatchers.IO).launch {
            DitoDatabase.getInstance(context).ditoNotificationDao().insert(record)
        }

        val rawData = remoteMessage.data.toMap()
        Dito.notificationReceivedListener?.invoke(rawData)
        DitoMessagingService.notificationInterceptor?.onNotificationReceived(rawData)
    }

    @RequiresApi(Build.VERSION_CODES.O)
    fun handleNewToken(token: String) {
        Log.d(TAG, "New FCM token received")
        try {
            if (!Dito.isInitialized()) {
                Dito.init(context, null)
            }
            Dito.registerDevice(token)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to register device token: ${e.message}")
        }
    }

    /**
     * Dump em linha única do data map completo do FCM, com prefixo estável para grep no logcat.
     * Só sai com `Options.debug = true` (T9.1).
     */
    private fun logPayload(remoteMessage: RemoteMessage) {
        if (Dito.options?.debug != true) return
        val data = remoteMessage.data.entries.joinToString(separator = "&") { (key, value) ->
            "$key=${value.replace("\n", "\\n")}"
        }
        val notification = remoteMessage.notification
        Log.d(
            TAG,
            "$PAYLOAD_LOG_PREFIX message_id=${remoteMessage.messageId ?: ""} " +
                "from=${remoteMessage.from ?: ""} data_keys=${remoteMessage.data.keys.sorted()} " +
                "has_notification_block=${notification != null} " +
                "notification_image=${notification?.imageUrl ?: ""} data={$data}",
        )
    }

    private fun getApplicationName(): String {
        return context.applicationInfo.loadLabel(context.packageManager).toString()
    }
}
