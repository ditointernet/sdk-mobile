package br.com.dito.ditosdk.offline

import android.content.Context
import android.os.Build
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
