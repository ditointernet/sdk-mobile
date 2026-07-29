package br.com.dito.ditosdk.notification

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.PendingIntent.*
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import br.com.dito.ditosdk.Dito
import br.com.dito.ditosdk.R
import java.io.BufferedInputStream
import java.net.HttpURLConnection
import java.net.URL

object NotificationDisplayHelper {

    private const val TAG = "NotificationDisplayHelper"

    /** Prefixo estável para grep do dump de payload (T9.1). */
    private const val PAYLOAD_LOG_PREFIX = "DITO_PUSH_DISPLAY"

    private const val IMAGE_CONNECT_TIMEOUT_MS = 5_000
    private const val IMAGE_READ_TIMEOUT_MS = 10_000

    @SuppressLint("MissingPermission")
    fun showNotification(
        context: Context,
        title: String?,
        message: String,
        notificationId: String?,
        reference: String?,
        deepLink: String?,
        channel: String?,
        channelDescription: String?,
        userId: String? = null,
        options: DitoNotificationOptions = DitoNotificationOptions(),
        imageUrl: String? = null,
        actions: List<DitoNotificationAction> = emptyList(),
        customDataJson: String? = null,
    ) {
        Log.d(TAG, "showNotification called - Title: $title, Message: $message")

        val notificationIdInt = System.currentTimeMillis().toInt()

        val intent = Intent(context, NotificationOpenedActivity::class.java).apply {
            putExtra(Dito.DITO_NOTIFICATION_ID, notificationId)
            putExtra(Dito.DITO_NOTIFICATION_REFERENCE, reference)
            putExtra(Dito.DITO_DEEP_LINK, deepLink)
            putExtra(Dito.DITO_USER_ID, userId)
            putExtra(DitoNotificationActionReceiver.EXTRA_CUSTOM_DATA, customDataJson)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        val pendingIntent: PendingIntent = getActivity(
            context,
            0,
            intent,
            FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT
        )

        val smallIcon = resolveSmallIcon(context, options)
        Log.d(TAG, "Notification icon: $smallIcon")

        val channelId = context.getString(R.string.default_notification_channel_id)

        val soundUri = resolveSoundUri(context, options)

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationChannel = NotificationChannel(
                channelId,
                channel,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = channelDescription
                enableLights(true)
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(notificationChannel)
            Log.d(TAG, "Notification channel created: $channelId")
        }

        val notificationBuilder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(smallIcon)
            .setContentTitle(title)
            .setContentText(message)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setSound(soundUri)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        options.largeIconResId?.let { resId ->
            val largeBitmap = BitmapFactory.decodeResource(context.resources, resId)
            if (largeBitmap != null) {
                notificationBuilder.setLargeIcon(largeBitmap)
            }
        }

        options.accentColor?.let { color ->
            notificationBuilder.setColor(color)
        }

        val bigPicture = downloadImage(imageUrl)
        if (bigPicture != null) {
            notificationBuilder
                .setLargeIcon(bigPicture)
                .setStyle(
                    NotificationCompat.BigPictureStyle()
                        .bigPicture(bigPicture)
                        .bigLargeIcon(null as Bitmap?)
                        .setSummaryText(message)
                )
        }

        addNotificationActions(
            context = context,
            builder = notificationBuilder,
            actions = actions,
            notificationId = notificationId,
            reference = reference,
            userId = userId,
            customDataJson = customDataJson,
            systemNotificationId = notificationIdInt,
        )

        Log.d(TAG, "=== Notification Details ===")
        Log.d(TAG, "Title: $title")
        Log.d(TAG, "Message: $message")
        Log.d(TAG, "Channel ID: $channelId")
        Log.d(TAG, "Small Icon: $smallIcon")
        Log.d(TAG, "Notification ID: $notificationIdInt")
        logRichPayload(
            notificationId = notificationId,
            reference = reference,
            deepLink = deepLink,
            imageUrl = imageUrl,
            imageDownloaded = bigPicture != null,
            actions = actions,
            customDataJson = customDataJson,
            systemNotificationId = notificationIdInt,
        )

        try {
            val notification = notificationBuilder.build()
            notificationManager.notify(notificationIdInt, notification)
        } catch (e: Exception) {
        }
    }

    /**
     * Adiciona um `addAction` por botão. O `PendingIntent` aponta para a [NotificationOpenedActivity]
     * (e não direto para o [DitoNotificationActionReceiver]) porque, a partir do Android 12, um
     * receiver acionado por notificação não pode iniciar Activities. A Activity abre o link e dispara
     * o broadcast `NOTIFICATION_ACTION_CLICK`, que o receiver consome para registrar o clique.
     */
    private fun addNotificationActions(
        context: Context,
        builder: NotificationCompat.Builder,
        actions: List<DitoNotificationAction>,
        notificationId: String?,
        reference: String?,
        userId: String?,
        customDataJson: String?,
        systemNotificationId: Int,
    ) {
        if (actions.isEmpty()) return

        actions.forEachIndexed { index, notificationAction ->
            val actionIntent = Intent(context, NotificationOpenedActivity::class.java).apply {
                putExtra(Dito.DITO_NOTIFICATION_ID, notificationId)
                putExtra(Dito.DITO_NOTIFICATION_REFERENCE, reference)
                putExtra(Dito.DITO_DEEP_LINK, notificationAction.link)
                putExtra(Dito.DITO_USER_ID, userId)
                putExtra(DitoNotificationActionReceiver.EXTRA_ACTION_ID, notificationAction.id)
                putExtra(DitoNotificationActionReceiver.EXTRA_ACTION_LABEL, notificationAction.label)
                putExtra(DitoNotificationActionReceiver.EXTRA_CUSTOM_DATA, customDataJson)
                putExtra(
                    DitoNotificationActionReceiver.EXTRA_SYSTEM_NOTIFICATION_ID,
                    systemNotificationId,
                )
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }

            // requestCode distinto por botão: PendingIntent.filterEquals ignora extras, então
            // sem isso os botões compartilhariam o mesmo PendingIntent.
            val actionPendingIntent = getActivity(
                context,
                systemNotificationId + index + 1,
                actionIntent,
                FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT
            )

            builder.addAction(0, notificationAction.label, actionPendingIntent)
        }
    }

    /**
     * Baixa a imagem do push de forma síncrona. Roda na thread do `onMessageReceived` do FCM (background).
     * Qualquer falha (rede, timeout, imagem inválida) volta `null` e a notificação cai no BigTextStyle.
     */
    internal fun downloadImage(imageUrl: String?): Bitmap? {
        if (imageUrl.isNullOrBlank()) return null
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(imageUrl).openConnection() as HttpURLConnection).apply {
                connectTimeout = IMAGE_CONNECT_TIMEOUT_MS
                readTimeout = IMAGE_READ_TIMEOUT_MS
                instanceFollowRedirects = true
                doInput = true
            }
            connection.inputStream.use { stream ->
                BitmapFactory.decodeStream(BufferedInputStream(stream))
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to download notification image: ${e.message}")
            null
        } finally {
            try {
                connection?.disconnect()
            } catch (_: Exception) {
            }
        }
    }

    /**
     * Dump em linha única dos campos ricos, com prefixo estável para grep no logcat.
     * Só sai com `Options.debug = true` (T9.1).
     */
    private fun logRichPayload(
        notificationId: String?,
        reference: String?,
        deepLink: String?,
        imageUrl: String?,
        imageDownloaded: Boolean,
        actions: List<DitoNotificationAction>,
        customDataJson: String?,
        systemNotificationId: Int,
    ) {
        if (Dito.options?.debug != true) return
        val actionsDump = actions.joinToString(separator = "|") { "${it.id}=${it.label}->${it.link}" }
        Log.d(
            TAG,
            "$PAYLOAD_LOG_PREFIX notification=$notificationId reference=$reference " +
                "system_id=$systemNotificationId deep_link=$deepLink image=$imageUrl " +
                "image_downloaded=$imageDownloaded actions_count=${actions.size} " +
                "actions=[$actionsDump] custom_data=${customDataJson ?: ""}",
        )
    }

    internal fun resolveSmallIcon(context: Context, options: DitoNotificationOptions): Int {
        options.smallIconResId?.let { resId ->
            if (resId != 0) return resId
        }
        return getNotificationIcon(context)
    }

    internal fun resolveSoundUri(context: Context, options: DitoNotificationOptions): Uri {
        val soundName = options.soundResourceName
        if (!soundName.isNullOrEmpty()) {
            return Uri.parse("android.resource://${context.packageName}/raw/$soundName")
        }
        return RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
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
