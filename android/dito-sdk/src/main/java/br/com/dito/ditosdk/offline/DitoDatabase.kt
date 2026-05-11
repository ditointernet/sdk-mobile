package br.com.dito.ditosdk.offline

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import br.com.dito.ditosdk.notification.inbox.DitoNotificationDao
import br.com.dito.ditosdk.notification.inbox.DitoNotificationRecord

val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS dito_notifications (
                id TEXT NOT NULL PRIMARY KEY,
                notification_id TEXT NOT NULL,
                reference TEXT NOT NULL,
                title TEXT NOT NULL,
                message TEXT NOT NULL,
                link TEXT NOT NULL,
                received_at INTEGER NOT NULL,
                is_read INTEGER NOT NULL DEFAULT 0
            )
            """.trimIndent()
        )
    }
}

@Database(
    entities = [DitoNotificationRecord::class],
    version = 2,
    exportSchema = false,
)
abstract class DitoDatabase : RoomDatabase() {

    abstract fun ditoNotificationDao(): DitoNotificationDao

    companion object {
        @Volatile
        private var instance: DitoDatabase? = null

        fun getInstance(context: Context): DitoDatabase =
            instance ?: synchronized(this) {
                instance ?: build(context.applicationContext).also { instance = it }
            }

        fun build(context: Context): DitoDatabase =
            Room.databaseBuilder(context, DitoDatabase::class.java, "dito-inbox")
                .addMigrations(MIGRATION_1_2)
                .build()
    }
}
