package br.com.dito.ditosdk.offline

import android.content.Context
import android.os.Build
import androidx.room.Room
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [Build.VERSION_CODES.O])
class DitoSqlHelperMigrationTest {

    private companion object {
        const val DB_NAME = "dito-offline-migration-test"
    }

    private lateinit var context: Context

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        context.deleteDatabase(DB_NAME)
    }

    @After
    fun tearDown() {
        context.deleteDatabase(DB_NAME)
    }

    @Test
    fun `migration 3 to 4 adds the click data column keeping pending clicks`() {
        openV3Database().use { db ->
            // Um clique já enfileirado, esperando reenvio.
            db.execSQL(
                "INSERT INTO notification (activityId, notificationId, identifier, retry) " +
                    "VALUES ('act1', 'notif1', 'user1', 2)"
            )

            OFFLINE_MIGRATION_3_4.migrate(db)

            // A fila é o que esta migração existe para preservar: destruí-la apagaria exatamente os
            // cliques que ainda não chegaram ao backend.
            db.query("SELECT activityId, retry, dataJson FROM notification WHERE notificationId = 'notif1'")
                .use { cursor ->
                    assertThat(cursor.moveToFirst()).isTrue()
                    assertThat(cursor.getString(0)).isEqualTo("act1")
                    assertThat(cursor.getInt(1)).isEqualTo(2)
                    assertThat(cursor.isNull(2)).isTrue()
                }
        }
    }

    @Test
    fun `migration 4 to 5 adds anonymous keeping pending events`() {
        openV4Database().use { db ->
            db.execSQL(
                "INSERT INTO event (activityId, action, timestamp, retry) VALUES ('act1', 'compra', 't', 2)"
            )
        }

        // Abrir pelo Room valida o schema migrado contra a entidade (tipo, NOT NULL e default).
        val room = Room.databaseBuilder(context, DitoSqlHelper::class.java, DB_NAME)
            .addMigrations(OFFLINE_MIGRATION_4_5, OFFLINE_MIGRATION_5_6, OFFLINE_MIGRATION_6_7)
            .allowMainThreadQueries()
            .build()
        try {
            val event = room.eventDao().getAll().single()
            assertThat(event.activityId).isEqualTo("act1")
            assertThat(event.retry).isEqualTo(2)
            assertThat(event.anonymous).isFalse()
        } finally {
            room.close()
        }
    }

    @Test
    fun `migration 5 to 6 adds log id and notification name keeping pending clicks`() {
        openV4Database().use { db ->
            db.execSQL(
                "INSERT INTO notification (activityId, notificationId, identifier, retry) " +
                    "VALUES ('act1', 'notif1', 'user1', 2)"
            )
            OFFLINE_MIGRATION_4_5.migrate(db)
            db.version = 5
        }

        val room = Room.databaseBuilder(context, DitoSqlHelper::class.java, DB_NAME)
            .addMigrations(OFFLINE_MIGRATION_5_6, OFFLINE_MIGRATION_6_7)
            .allowMainThreadQueries()
            .build()
        try {
            val click = room.notificationDao().getAll().single()
            assertThat(click.activityId).isEqualTo("act1")
            assertThat(click.retry).isEqualTo(2)
            assertThat(click.logId).isNull()
            assertThat(click.notificationName).isNull()
        } finally {
            room.close()
        }
    }

    @Test
    fun `migration 6 to 7 adds the owner keeping pending events`() {
        openV4Database().use { db ->
            OFFLINE_MIGRATION_4_5.migrate(db)
            OFFLINE_MIGRATION_5_6.migrate(db)
            db.execSQL(
                "INSERT INTO event (activityId, action, timestamp, retry, anonymous) VALUES ('act1', 'compra', 't', 2, 1)"
            )
            db.version = 6
        }

        val room = Room.databaseBuilder(context, DitoSqlHelper::class.java, DB_NAME)
            .addMigrations(OFFLINE_MIGRATION_6_7)
            .allowMainThreadQueries()
            .build()
        try {
            val event = room.eventDao().getAll().single()
            assertThat(event.activityId).isEqualTo("act1")
            assertThat(event.retry).isEqualTo(2)
            assertThat(event.anonymous).isTrue()
            assertThat(event.userId).isNull()
        } finally {
            room.close()
        }
    }

    private fun openV4Database(): SupportSQLiteDatabase {
        val helper = FrameworkSQLiteOpenHelperFactory().create(
            SupportSQLiteOpenHelper.Configuration.builder(context)
                .name(DB_NAME)
                .callback(object : SupportSQLiteOpenHelper.Callback(4) {
                    override fun onCreate(db: SupportSQLiteDatabase) {
                        db.execSQL(
                            "CREATE TABLE IF NOT EXISTS `identify` (`_id` TEXT NOT NULL, `name` TEXT, " +
                                "`email` TEXT, `gender` TEXT, `birthday` TEXT, `location` TEXT, " +
                                "`customDataJson` TEXT, `send` INTEGER NOT NULL, PRIMARY KEY(`_id`))"
                        )
                        db.execSQL(
                            "CREATE TABLE IF NOT EXISTS `event` (`_id` INTEGER PRIMARY KEY AUTOINCREMENT, " +
                                "`activityId` TEXT NOT NULL, `action` TEXT NOT NULL, `revenue` REAL, " +
                                "`dataJson` TEXT, `timestamp` TEXT NOT NULL, `retry` INTEGER NOT NULL)"
                        )
                        db.execSQL(
                            "CREATE TABLE IF NOT EXISTS `notification` (`_id` INTEGER PRIMARY KEY AUTOINCREMENT, " +
                                "`activityId` TEXT NOT NULL, `notificationId` TEXT NOT NULL, " +
                                "`identifier` TEXT NOT NULL, `retry` INTEGER NOT NULL, `dataJson` TEXT)"
                        )
                    }

                    override fun onUpgrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
                })
                .build()
        )
        return helper.writableDatabase
    }

    private fun openV3Database(): SupportSQLiteDatabase {
        val helper = FrameworkSQLiteOpenHelperFactory().create(
            SupportSQLiteOpenHelper.Configuration.builder(context)
                .name(DB_NAME)
                .callback(object : SupportSQLiteOpenHelper.Callback(3) {
                    override fun onCreate(db: SupportSQLiteDatabase) {
                        // Schema da v3 exatamente como o Room o cria, para que o ALTER TABLE da
                        // migração seja exercitado contra a tabela real, não contra uma aproximação.
                        db.execSQL(
                            """
                            CREATE TABLE IF NOT EXISTS `notification` (
                                `_id` INTEGER PRIMARY KEY AUTOINCREMENT,
                                `activityId` TEXT NOT NULL,
                                `notificationId` TEXT NOT NULL,
                                `identifier` TEXT NOT NULL,
                                `retry` INTEGER NOT NULL
                            )
                            """.trimIndent()
                        )
                    }

                    override fun onUpgrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
                })
                .build()
        )
        return helper.writableDatabase
    }
}
