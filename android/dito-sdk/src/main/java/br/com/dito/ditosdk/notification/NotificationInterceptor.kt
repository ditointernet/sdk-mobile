package br.com.dito.ditosdk.notification

import com.google.firebase.messaging.RemoteMessage

interface NotificationInterceptor {
    fun onNotificationReceived(remoteMessage: RemoteMessage)
    fun onNotificationReceived(userInfo: Map<String, String>) {}
}
