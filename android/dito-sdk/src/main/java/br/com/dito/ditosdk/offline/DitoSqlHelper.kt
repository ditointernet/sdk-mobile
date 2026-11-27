package br.com.dito.ditosdk.offline

import androidx.room.ColumnInfo
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Entity(tableName = "identify")
internal data class IdentifyOffline(
    @PrimaryKey val _id: String,
    val name: String?,
    val email: String?,
    val gender: String?,
    val birthday: String?,
    val location: String?,
    val customDataJson: String?,
    val send: Boolean,
)

@Dao
internal interface IdentifyOfflineDao {
    @Query("SELECT * FROM identify")
    fun getAll(): List<IdentifyOffline>

    @Query("SELECT * FROM identify LIMIT 1")
    fun getFirst(): IdentifyOffline

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun insert(vararg identify: IdentifyOffline)

    @Query("UPDATE identify SET send=:send WHERE _id =:id")
    fun update(send: Boolean, id: String)

    @Query("DELETE FROM identify WHERE _id =:id")
    fun delete(id: String)

    @Query("DELETE FROM identify")
    fun deleteAll()
}

@Entity(tableName = "event")
internal data class EventOffline(
    @PrimaryKey(autoGenerate = true) val _id: Int? = null,
    val activityId: String,
    val action: String,
    val revenue: Float?,
    val dataJson: String?,
    val timestamp: String,
    val retry: Int,
    @ColumnInfo(defaultValue = "0") val anonymous: Boolean = false,
    /** user_id de quando a linha entrou na fila; nulo em linha anônima ou anterior à coluna. */
    val userId: String? = null,
)

@Dao
internal interface EventOfflineDao {
    @Query("SELECT * FROM event")
    fun getAll(): List<EventOffline>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun insert(vararg event: EventOffline)

    @Query("UPDATE event SET retry=:retry WHERE _id =:id")
    fun update(id: Int, retry: Int)

    @Query("DELETE FROM event WHERE _id =:id")
    fun delete(id: Int)
}

@Entity(tableName = "notification")
internal data class NotificationOffline(
    @PrimaryKey(autoGenerate = true) val _id: Int? = null,
    val activityId: String,
    val notificationId: String,
    val identifier: String,
    val retry: Int,
    /**
     * Custom data do clique (`action_id` / `action_label`) serializada em JSON. Sem esta coluna o
     * reenvio contava o clique sem dizer qual botão foi tocado, e a atribuição se perdia em
     * silêncio. Nulo quando o clique foi no corpo da notificação.
     */
    val dataJson: String? = null,
    val logId: String? = null,
    val notificationName: String? = null,
    /** Hora do enfileiramento; nula em linha anterior à coluna (o reenvio usa a hora atual). */
    val timestamp: String? = null,
)

@Dao
internal interface NotificationOfflineDao {
    @Query("SELECT * FROM notification")
    fun getAll(): List<NotificationOffline>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun insert(vararg notification: NotificationOffline)

    @Query("UPDATE notification SET retry=:retry WHERE _id =:id")
    fun update(id: Int, retry: Int)

    @Query("DELETE FROM notification WHERE _id =:id")
    fun delete(id: Int)
}

/**
 * Adiciona `dataJson` à fila de cliques. Migração aditiva e nullable — nenhuma linha pendente é
 * perdida, e é isso que importa aqui: a alternativa (`fallbackToDestructiveMigration`) apagaria
 * exatamente os cliques que ainda não foram entregues.
 */
internal val OFFLINE_MIGRATION_3_4 = object : Migration(3, 4) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE notification ADD COLUMN dataJson TEXT")
    }
}

// Sem ela, o fallbackToDestructiveMigration apaga a fila de eventos pendentes.
internal val OFFLINE_MIGRATION_4_5 = object : Migration(4, 5) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE event ADD COLUMN anonymous INTEGER NOT NULL DEFAULT 0")
    }
}

internal val OFFLINE_MIGRATION_5_6 = object : Migration(5, 6) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE notification ADD COLUMN logId TEXT")
        db.execSQL("ALTER TABLE notification ADD COLUMN notificationName TEXT")
    }
}

// Sem ela, o fallbackToDestructiveMigration apaga a fila de eventos pendentes.
internal val OFFLINE_MIGRATION_6_7 = object : Migration(6, 7) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE event ADD COLUMN userId TEXT")
        db.execSQL("ALTER TABLE notification ADD COLUMN timestamp TEXT")
    }
}

@Database(
    entities = [IdentifyOffline::class, EventOffline::class, NotificationOffline::class],
    version = 7,
    exportSchema = false,
)
internal abstract class DitoSqlHelper : RoomDatabase() {
    abstract fun identifyDao(): IdentifyOfflineDao
    abstract fun eventDao(): EventOfflineDao
    abstract fun notificationDao(): NotificationOfflineDao
}
