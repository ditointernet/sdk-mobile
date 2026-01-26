package br.com.dito.example_app

import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import br.com.dito.ditosdk.notification.DitoNotificationHandler
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class CustomMessagingService : FirebaseMessagingService() {

    private val ditoHandler by lazy { DitoNotificationHandler(applicationContext) }

    @RequiresApi(Build.VERSION_CODES.O)
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "📬 Notification received from: ${remoteMessage.from}")
        Log.d(TAG, "Data: ${remoteMessage.data}")

        NotificationDebugHelper.saveNotificationPayload(applicationContext, remoteMessage)

        when {
            ditoHandler.canHandle(remoteMessage) -> {
                Log.d(TAG, "✅ Delegating to Dito handler")
                ditoHandler.handleNotification(remoteMessage)
            }

            isOneSignalNotification(remoteMessage) -> {
                Log.d(TAG, "✅ OneSignal notification detected")
                handleOneSignalNotification(remoteMessage)
            }

            isCustomNotification(remoteMessage) -> {
                Log.d(TAG, "✅ Custom notification detected")
                handleCustomNotification(remoteMessage)
            }

            else -> {
                Log.d(TAG, "⚠️ Unknown notification type, using default handler")
                handleDefaultNotification(remoteMessage)
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "🔄 New FCM token: $token")

        ditoHandler.handleNewToken(token)

        handleOneSignalToken(token)

        handleCustomToken(token)
    }

    private fun isOneSignalNotification(remoteMessage: RemoteMessage): Boolean {
        return remoteMessage.data.containsKey("custom") &&
               remoteMessage.data["custom"]?.contains("\"i\":") == true
    }

    private fun handleOneSignalNotification(remoteMessage: RemoteMessage) {
        Log.d(TAG, "OneSignal notification handling would go here")
    }

    private fun handleOneSignalToken(token: String) {
        Log.d(TAG, "OneSignal token registration would go here")
    }

    private fun isCustomNotification(remoteMessage: RemoteMessage): Boolean {
        return remoteMessage.data.containsKey("custom_type")
    }

    private fun handleCustomNotification(remoteMessage: RemoteMessage) {
        Log.d(TAG, "Custom notification handling: ${remoteMessage.data["custom_type"]}")
    }

    private fun handleCustomToken(token: String) {
        Log.d(TAG, "Custom token registration would go here")
    }

    private fun handleDefaultNotification(remoteMessage: RemoteMessage) {
        Log.d(TAG, "Default notification handler")
    }

    companion object {
        private const val TAG = "CustomMessagingService"
    }
}
