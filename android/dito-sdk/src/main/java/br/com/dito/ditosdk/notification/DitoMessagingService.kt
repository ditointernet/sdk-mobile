package br.com.dito.ditosdk.notification

import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class DitoMessagingService : FirebaseMessagingService() {

    companion object {
        var notificationInterceptor: NotificationInterceptor? = null
    }

    private val handler by lazy { DitoNotificationHandler(applicationContext) }

    @RequiresApi(Build.VERSION_CODES.O)
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        notificationInterceptor?.onNotificationReceived(remoteMessage)

        if (handler.canHandle(remoteMessage)) {
            handler.handleNotification(remoteMessage)
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        handler.handleNewToken(token)
    }

}
