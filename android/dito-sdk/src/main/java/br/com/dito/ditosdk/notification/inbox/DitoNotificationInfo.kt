package br.com.dito.ditosdk.notification.inbox

data class DitoNotificationInfo(
    val id: String,
    val notificationId: String,
    val reference: String,
    val title: String,
    val message: String,
    val link: String,
    val receivedAt: Long,
    val isRead: Boolean,
)
