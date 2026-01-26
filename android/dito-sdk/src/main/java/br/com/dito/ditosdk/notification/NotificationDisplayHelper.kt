package br.com.dito.ditosdk.notification

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.PendingIntent.*
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import br.com.dito.ditosdk.Dito
import br.com.dito.ditosdk.R

object NotificationDisplayHelper {

    private const val TAG = "NotificationDisplayHelper"

    @SuppressLint("MissingPermission")
    fun showNotification(
        context: Context,
        title: String?,
        message: String,
        notificationId: String?,
        reference: String?,
        deepLink: String?,
        channel: String?,
        channelDescription: String?
    ) {
        Log.d(TAG, "showNotification called - Title: $title, Message: $message")

        val intent = Intent(context, NotificationOpenedActivity::class.java).apply {
            putExtra(Dito.DITO_NOTIFICATION_ID, notificationId)
            putExtra(Dito.DITO_NOTIFICATION_REFERENCE, reference)
            putExtra(Dito.DITO_DEEP_LINK, deepLink)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        val pendingIntent: PendingIntent = getActivity(
            context,
            0,
            intent,
            FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT
        )

        val smallIcon = getNotificationIcon(context)
        Log.d(TAG, "Notification icon: $smallIcon")

        val channelId = context.getString(R.string.default_notification_channel_id)
        val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channel,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = channelDescription
                enableLights(true)
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created: $channelId")
        }

        val notificationBuilder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(smallIcon)
            .setContentTitle(title)
            .setContentText(message)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setSound(defaultSoundUri)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        val notificationIdInt = System.currentTimeMillis().toInt()

        Log.d(TAG, "=== Notification Details ===")
        Log.d(TAG, "Title: $title")
        Log.d(TAG, "Message: $message")
        Log.d(TAG, "Channel ID: $channelId")
        Log.d(TAG, "Small Icon: $smallIcon")
        Log.d(TAG, "Notification ID: $notificationIdInt")

        try {
            val notification = notificationBuilder.build()
            notificationManager.notify(notificationIdInt, notification)
        } catch (e: Exception) {
        }
    }

    private fun getNotificationIcon(context: Context): Int {
        val customIcon = Dito.options?.iconNotification
        if (customIcon != null && customIcon != 0) {
            return customIcon
        }

        val appIcon = context.applicationInfo.icon
        if (appIcon != 0) {
            return appIcon
        }

        return android.R.drawable.ic_dialog_info
    }
}
