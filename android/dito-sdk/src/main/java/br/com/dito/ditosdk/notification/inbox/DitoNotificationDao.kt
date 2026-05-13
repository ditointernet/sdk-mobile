package br.com.dito.ditosdk.notification.inbox

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface DitoNotificationDao {

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insert(record: DitoNotificationRecord)

    @Query("SELECT * FROM dito_notifications ORDER BY received_at DESC")
    suspend fun getAll(): List<DitoNotificationRecord>

    @Query("UPDATE dito_notifications SET is_read = 1 WHERE id = :id")
    suspend fun markAsRead(id: String)

    @Query("UPDATE dito_notifications SET is_read = 1 WHERE notification_id = :notificationId")
    suspend fun markAsReadByNotificationId(notificationId: String)
}
