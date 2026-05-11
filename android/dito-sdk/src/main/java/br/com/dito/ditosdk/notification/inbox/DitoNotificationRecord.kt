package br.com.dito.ditosdk.notification.inbox

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "dito_notifications")
data class DitoNotificationRecord(
    @PrimaryKey
    @ColumnInfo(name = "id")
    val id: String,

    @ColumnInfo(name = "notification_id")
    val notificationId: String,

    @ColumnInfo(name = "reference")
    val reference: String,

    @ColumnInfo(name = "title")
    val title: String,

    @ColumnInfo(name = "message")
    val message: String,

    @ColumnInfo(name = "link")
    val link: String,

    @ColumnInfo(name = "received_at")
    val receivedAt: Long,

    @ColumnInfo(name = "is_read")
    val isRead: Boolean = false,
)
