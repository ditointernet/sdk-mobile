package br.com.dito.example_app

import android.content.Context
import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object NotificationDebugHelper {

    private const val TAG = "NotificationDebugHelper"
    private const val DEBUG_DIR = "dito_notifications_debug"

    fun saveNotificationPayload(context: Context, remoteMessage: RemoteMessage) {
        try {
            val debugDir = File(context.filesDir, DEBUG_DIR)
            if (!debugDir.exists()) {
                debugDir.mkdirs()
            }

            val timestamp = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault()).format(Date())
            val filename = "notification_$timestamp.json"
            val file = File(debugDir, filename)

            val payload = JSONObject().apply {
                put("timestamp", timestamp)
                put("messageId", remoteMessage.messageId ?: "")
                put("from", remoteMessage.from ?: "")
                put("to", remoteMessage.to ?: "")
                put("messageType", remoteMessage.messageType ?: "")
                put("collapseKey", remoteMessage.collapseKey ?: "")
                put("ttl", remoteMessage.ttl)
                put("sentTime", remoteMessage.sentTime)

                val dataJson = JSONObject()
                remoteMessage.data.forEach { (key, value) ->
                    dataJson.put(key, value)
                }
                put("data", dataJson)

                remoteMessage.notification?.let { notification ->
                    val notificationJson = JSONObject().apply {
                        put("title", notification.title ?: "")
                        put("body", notification.body ?: "")
                        put("icon", notification.icon ?: "")
                        put("sound", notification.sound ?: "")
                        put("tag", notification.tag ?: "")
                        put("color", notification.color ?: "")
                        put("clickAction", notification.clickAction ?: "")
                    }
                    put("notification", notificationJson)
                }
            }

            file.writeText(payload.toString(2))
            Log.d(TAG, "Notification payload saved to: ${file.absolutePath}")
            Log.d(TAG, "Payload content:\n${payload.toString(2)}")

            cleanOldFiles(debugDir)
        } catch (e: Exception) {
            Log.e(TAG, "Error saving notification payload: ${e.message}", e)
        }
    }

    fun getLatestNotificationFile(context: Context): File? {
        val debugDir = File(context.filesDir, DEBUG_DIR)
        if (!debugDir.exists()) return null

        return debugDir.listFiles()
            ?.filter { it.name.startsWith("notification_") && it.name.endsWith(".json") }
            ?.maxByOrNull { it.lastModified() }
    }

    fun getAllNotificationFiles(context: Context): List<File> {
        val debugDir = File(context.filesDir, DEBUG_DIR)
        if (!debugDir.exists()) return emptyList()

        return debugDir.listFiles()
            ?.filter { it.name.startsWith("notification_") && it.name.endsWith(".json") }
            ?.sortedByDescending { it.lastModified() }
            ?: emptyList()
    }

    fun readNotificationPayload(file: File): String {
        return try {
            file.readText()
        } catch (e: Exception) {
            Log.e(TAG, "Error reading notification file: ${e.message}", e)
            ""
        }
    }

    private fun cleanOldFiles(directory: File, maxFiles: Int = 10) {
        try {
            val files = directory.listFiles()
                ?.filter { it.name.startsWith("notification_") && it.name.endsWith(".json") }
                ?.sortedByDescending { it.lastModified() }
                ?: return

            if (files.size > maxFiles) {
                files.drop(maxFiles).forEach { file ->
                    file.delete()
                    Log.d(TAG, "Deleted old notification file: ${file.name}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error cleaning old files: ${e.message}", e)
        }
    }

    fun simulateNotification(context: Context, jsonPayload: String): RemoteMessage? {
        return try {
            val json = JSONObject(jsonPayload)
            val dataJson = json.optJSONObject("data") ?: JSONObject()

            val dataMap = mutableMapOf<String, String>()
            dataJson.keys().forEach { key ->
                dataMap[key] = dataJson.getString(key)
            }

            val builder = RemoteMessage.Builder("test_sender_id")
            dataMap.forEach { (key, value) ->
                builder.addData(key, value)
            }

            json.optString("messageId")?.let { if (it.isNotEmpty()) builder.setMessageId(it) }
            json.optString("messageType")?.let { if (it.isNotEmpty()) builder.setMessageType(it) }
            json.optString("collapseKey")?.let { if (it.isNotEmpty()) builder.setCollapseKey(it) }

            if (json.has("ttl")) {
                builder.setTtl(json.getInt("ttl"))
            }

            builder.build()
        } catch (e: Exception) {
            Log.e(TAG, "Error simulating notification: ${e.message}", e)
            null
        }
    }
}
