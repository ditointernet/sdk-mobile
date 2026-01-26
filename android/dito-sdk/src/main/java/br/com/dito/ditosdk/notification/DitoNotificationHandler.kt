package br.com.dito.ditosdk.notification

import android.content.Context
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import br.com.dito.ditosdk.Dito
import br.com.dito.ditosdk.Dito.NotificationReadData
import com.google.firebase.messaging.RemoteMessage

class DitoNotificationHandler(private val context: Context) {

    companion object {
        private const val TAG = "DitoNotificationHandler"
        private const val CHANNEL_KEY = "channel"
        private const val CHANNEL_VALUE = "DITO"
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

        val notificationId = remoteMessage.data["notification"] ?: ""
        val reference = remoteMessage.data["reference"] ?: ""
        val deepLink = remoteMessage.data["link"] ?: ""
        val title = remoteMessage.data["title"]?.takeIf { it.isNotEmpty() } ?: getApplicationName()
        val message = remoteMessage.data["message"] ?: ""
        val logId = remoteMessage.data["log_id"] ?: ""
        val notificationName = remoteMessage.data["notification_name"] ?: ""
        val userId = remoteMessage.data["user_id"] ?: ""

        if (notificationId.isNotEmpty() && reference.isNotEmpty()) {
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
        }

        NotificationDisplayHelper.showNotification(
            context = context,
            title = title,
            message = message,
            notificationId = notificationId,
            reference = reference,
            deepLink = deepLink,
            channel = getApplicationName() + " notifications",
            channelDescription = getApplicationName() + " application notifications"
        )
    }

    @RequiresApi(Build.VERSION_CODES.O)
    fun handleNewToken(token: String) {
        Log.d(TAG, "New FCM token received")
        if (!Dito.isInitialized()) {
            Dito.init(context, null)
        }
        Dito.registerDevice(token)
    }

    private fun getApplicationName(): String {
        return context.applicationInfo.loadLabel(context.packageManager).toString()
    }
}
