package br.com.dito.ditosdk.tracking

import android.content.Context
import android.util.Log
import androidx.room.Room
import br.com.dito.ditosdk.Event
import br.com.dito.ditosdk.EventOff
import br.com.dito.ditosdk.Identify
import br.com.dito.ditosdk.IdentifyOff
import br.com.dito.ditosdk.NotificationReadOff
import br.com.dito.ditosdk.offline.DitoSqlHelper
import br.com.dito.ditosdk.offline.EventOffline
import br.com.dito.ditosdk.offline.IdentifyOffline
import br.com.dito.ditosdk.offline.NotificationOffline
import br.com.dito.ditosdk.offline.OFFLINE_MIGRATION_3_4
import br.com.dito.ditosdk.offline.OFFLINE_MIGRATION_4_5
import br.com.dito.ditosdk.offline.OFFLINE_MIGRATION_5_6
import br.com.dito.ditosdk.offline.OFFLINE_MIGRATION_6_7
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

internal class TrackerOffline(
    context: Context,
    useInMemoryDatabase: Boolean = false,
    allowMainThreadQueries: Boolean = false,
) {
    private val gson = Gson()
    internal val database = createDatabase(context, useInMemoryDatabase, allowMainThreadQueries)

    private fun createDatabase(
        context: Context,
        useInMemoryDatabase: Boolean,
        allowMainThreadQueries: Boolean,
    ): DitoSqlHelper {
        val builder = if (useInMemoryDatabase) {
            Room.inMemoryDatabaseBuilder(context, DitoSqlHelper::class.java)
        } else {
            Room.databaseBuilder(context, DitoSqlHelper::class.java, "dito-offline")
                .addMigrations(OFFLINE_MIGRATION_3_4, OFFLINE_MIGRATION_4_5, OFFLINE_MIGRATION_5_6, OFFLINE_MIGRATION_6_7)
                .fallbackToDestructiveMigration()
        }

        if (allowMainThreadQueries) {
            builder.allowMainThreadQueries()
        }

        return builder.build()
    }

    fun identify(identify: Identify, send: Boolean) {
        try {
            val customJson = identify.data?.params?.takeIf { it.isNotEmpty() }?.let { gson.toJson(it) }
            val row = IdentifyOffline(
                _id = identify.id,
                name = identify.name,
                email = identify.email,
                gender = identify.gender,
                birthday = identify.birthday,
                location = identify.location,
                customDataJson = customJson,
                send = send,
            )
            // Um identify só no disco: o arranque restaura a primeira linha.
            database.runInTransaction {
                database.identifyDao().deleteAll()
                database.identifyDao().insert(row)
            }
        } catch (e: Exception) {
            Log.e("TrackerOffline", e.message, e)
        }
    }

    fun updateIdentify(id: String, send: Boolean) {
        try {
            database.identifyDao().update(send, id)
        } catch (e: Exception) {
            Log.e("TrackerOffline", e.message, e)
        }
    }

    fun deleteIdentify() {
        try {
            database.identifyDao().deleteAll()
        } catch (e: Exception) {
            Log.e("TrackerOffline", e.message, e)
        }
    }

    fun event(event: Event, activityId: String, anonymous: Boolean = false, userId: String? = null) {
        try {
            val dataJson = event.data?.params?.takeIf { it.isNotEmpty() }?.let { gson.toJson(it) }
            database.eventDao().insert(
                EventOffline(
                    activityId = activityId,
                    action = event.action,
                    revenue = event.revenue?.toFloat(),
                    dataJson = dataJson,
                    timestamp = event.createdAt ?: "",
                    retry = 0,
                    anonymous = anonymous,
                    userId = userId,
                ),
            )
        } catch (e: Exception) {
            Log.e("TrackerOffline", e.message, e)
        }
    }

    fun delete(id: Int, tableName: String) {
        try {
            when (tableName) {
                "Event" -> database.eventDao().delete(id)
                "NotificationRead" -> database.notificationDao().delete(id)
            }
        } catch (e: Exception) {
            Log.e("TrackerOffline", e.message, e)
        }
    }

    fun update(id: Int, retry: Int, tableName: String) {
        try {
            when (tableName) {
                "Event" -> database.eventDao().update(id, retry)
                "NotificationRead" -> database.notificationDao().update(id, retry)
            }
        } catch (e: Exception) {
            Log.e("TrackerOffline", e.message, e)
        }
    }

    fun getAllEvents(): List<EventOff>? {
        return try {
            val events = database.eventDao().getAll()
            if (events.isEmpty()) {
                return null
            }
            events.map {
                EventOff(
                    it._id ?: 0,
                    it.activityId,
                    it.action,
                    it.revenue,
                    it.dataJson,
                    it.timestamp,
                    it.retry,
                    it.anonymous,
                    it.userId,
                )
            }
        } catch (e: Exception) {
            null
        }
    }

    fun getAllNotificationRead(): List<NotificationReadOff>? {
        return try {
            val notifications = database.notificationDao().getAll()
            if (notifications.isEmpty()) {
                return null
            }
            notifications.map {
                NotificationReadOff(
                    it._id ?: 0,
                    it.activityId,
                    it.notificationId,
                    it.identifier,
                    it.retry,
                    clickDataFromJson(it.dataJson),
                    it.logId.orEmpty(),
                    it.notificationName.orEmpty(),
                )
            }
        } catch (e: Exception) {
            null
        }
    }

    fun getIdentify(): IdentifyOff? {
        try {
            val identify = database.identifyDao().getAll().first()
            return IdentifyOff(
                id = identify._id,
                name = identify.name,
                email = identify.email,
                gender = identify.gender,
                birthday = identify.birthday,
                location = identify.location,
                customDataJson = identify.customDataJson,
                send = identify.send,
            )
        } catch (e: Exception) {
            return null
        }
    }

    fun notificationRead(
        activityId: String,
        notificationId: String,
        identifier: String,
        data: Map<String, String> = emptyMap(),
        logId: String = "",
        notificationName: String = "",
    ) {
        try {
            database.notificationDao().insert(
                NotificationOffline(
                    activityId = activityId,
                    notificationId = notificationId,
                    identifier = identifier,
                    retry = 0,
                    dataJson = data.takeIf { it.isNotEmpty() }?.let { gson.toJson(it) },
                    logId = logId,
                    notificationName = notificationName,
                ),
            )
        } catch (e: Exception) {
            Log.e("TrackerOffline", e.message, e)
        }
    }

    private fun clickDataFromJson(json: String?): Map<String, String> {
        if (json.isNullOrBlank()) return emptyMap()
        return try {
            gson.fromJson(json, clickDataType) ?: emptyMap()
        } catch (e: Exception) {
            // Fila corrompida não deve impedir o reenvio do clique: perde-se a atribuição do botão,
            // não o clique.
            Log.e("TrackerOffline", "custom data do clique ilegível: ${e.message}", e)
            emptyMap()
        }
    }

    private companion object {
        private val clickDataType = object : TypeToken<Map<String, String>>() {}.type
    }
}
