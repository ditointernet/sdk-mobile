package br.com.dito.ditosdk.offline

import android.content.Context
import android.os.Build
import androidx.room.Room
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.notification.inbox.DitoNotificationRecord
import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [Build.VERSION_CODES.O])
class DitoDatabaseMigrationTest {

    private companion object {
        const val DB_NAME = "dito-inbox-migration-test"
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
    fun `migration 2 to 3 adds rich push columns keeping existing rows`() {
        // Arrange: banco na versão 2 (schema criado pela MIGRATION_1_2) com uma notificação antiga
        openV2Database().use { db ->
            db.execSQL(
                "INSERT INTO dito_notifications " +
                    "(id, notification_id, reference, title, message, link, received_at, is_read) " +
                    "VALUES ('id1', 'notif1', 'ref1', 'Título', 'Mensagem', 'https://dito.com.br', 123, 0)"
            )

            // Act
            MIGRATION_2_3.migrate(db)

            // Assert: linha preservada e colunas novas com default vazio
            db.query(
                "SELECT title, link, image, custom_data FROM dito_notifications WHERE id = 'id1'"
            ).use { cursor ->
                assertThat(cursor.moveToFirst()).isTrue()
                assertThat(cursor.getString(0)).isEqualTo("Título")
                assertThat(cursor.getString(1)).isEqualTo("https://dito.com.br")
                assertThat(cursor.getString(2)).isEmpty()
                assertThat(cursor.getString(3)).isEmpty()
            }
        }
    }

    @Test
    fun `record round trip keeps image and custom data`() = runBlocking {
        // Arrange
        val db = Room.inMemoryDatabaseBuilder(context, DitoDatabase::class.java).build()
        val record = DitoNotificationRecord(
            id = "id1",
            notificationId = "notif1",
            reference = "ref1",
            title = "Título",
            message = "Mensagem",
            link = "https://dito.com.br",
            receivedAt = 123,
            isRead = false,
            image = "https://dito.com.br/banner.png",
            customData = """{"nivel_programa":"ouro"}""",
        )

        // Act
        db.ditoNotificationDao().insert(record)
        val stored = db.ditoNotificationDao().getAll().single()

        // Assert
        assertThat(stored.image).isEqualTo("https://dito.com.br/banner.png")
        assertThat(stored.customData).isEqualTo("""{"nivel_programa":"ouro"}""")
        db.close()
    }

    @Test
    fun `record defaults to empty rich push fields`() = runBlocking {
        // Arrange
        val db = Room.inMemoryDatabaseBuilder(context, DitoDatabase::class.java).build()
        val record = DitoNotificationRecord(
            id = "id1",
            notificationId = "notif1",
            reference = "ref1",
            title = "Título",
            message = "Mensagem",
            link = "",
            receivedAt = 123,
        )

        // Act
        db.ditoNotificationDao().insert(record)
        val stored = db.ditoNotificationDao().getAll().single()

        // Assert
        assertThat(stored.image).isEmpty()
        assertThat(stored.customData).isEmpty()
        db.close()
    }

    private fun openV2Database(): SupportSQLiteDatabase {
        val helper = FrameworkSQLiteOpenHelperFactory().create(
            SupportSQLiteOpenHelper.Configuration.builder(context)
                .name(DB_NAME)
                .callback(object : SupportSQLiteOpenHelper.Callback(2) {
                    override fun onCreate(db: SupportSQLiteDatabase) {
                        MIGRATION_1_2.migrate(db)
                    }

                    override fun onUpgrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
                })
                .build()
        )
        return helper.writableDatabase
    }
}
