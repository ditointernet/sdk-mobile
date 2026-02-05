package br.com.dito.ditosdk

import android.content.Context
import android.util.Log
import br.com.dito.ditosdk.notification.DitoNotificationHandler
import com.google.firebase.messaging.RemoteMessage

object DitoMessagingServiceHelper {
    private const val TAG = "DitoMessagingServiceHelper"

    fun handleMessage(context: Context, remoteMessage: RemoteMessage): Boolean {
        return try {
            val handler = DitoNotificationHandler(context)
            if (!handler.canHandle(remoteMessage)) {
                false
            } else {
                handler.handleNotification(remoteMessage)
                true
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to handle message: ${e.message}")
            false
        }
    }

    fun handleNewToken(context: Context, token: String) {
        try {
            val handler = DitoNotificationHandler(context)
            handler.handleNewToken(token)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to handle new token: ${e.message}")
        }
    }
}

