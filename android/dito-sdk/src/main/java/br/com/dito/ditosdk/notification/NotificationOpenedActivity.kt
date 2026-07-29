package br.com.dito.ditosdk.notification

import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.appcompat.app.AppCompatActivity
import br.com.dito.ditosdk.Dito

class NotificationOpenedActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "NotificationOpenedActivity"
    }

    @RequiresApi(Build.VERSION_CODES.O)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Log.d(TAG, "=== NotificationOpenedActivity onCreate ===")
        Log.d(TAG, "Intent action: ${intent?.action}")
        Log.d(TAG, "Intent extras: ${intent?.extras?.keySet()?.joinToString()}")

        var notificationId = intent?.getStringExtra(Dito.DITO_NOTIFICATION_ID)
        var reference = intent?.getStringExtra(Dito.DITO_NOTIFICATION_REFERENCE)
        var deepLink = intent?.getStringExtra(Dito.DITO_DEEP_LINK)

        if (notificationId == null || reference == null) {
            Log.d(TAG, "Extras not found, trying to get from FCM data extras")
            notificationId = intent?.getStringExtra("notification")
            reference = intent?.getStringExtra("reference")
            deepLink = intent?.getStringExtra("link")
        }

        Log.d(TAG, "Notification ID: $notificationId")
        Log.d(TAG, "Reference: $reference")
        Log.d(TAG, "Deep Link: $deepLink")

        if (!Dito.isInitialized()) {
            Log.d(TAG, "Dito not initialized, initializing...")
            Dito.init(applicationContext, null)
        }

        val actionId = intent?.getStringExtra(DitoNotificationActionReceiver.EXTRA_ACTION_ID) ?: ""
        if (actionId.isNotEmpty()) {
            dismissNotification()
        }

        if (reference != null && notificationId != null) {
            val userId = intent?.getStringExtra(Dito.DITO_USER_ID) ?: ""
            if (actionId.isNotEmpty()) {
                Log.d(TAG, "✅ Broadcasting notification action click: $actionId")
                broadcastActionClick(actionId, notificationId, reference, deepLink ?: "", userId)
            } else {
                Log.d(TAG, "✅ Calling Dito.notificationClick()")
                val userInfo = mapOf(
                    "notification" to notificationId,
                    "reference" to reference,
                    "deeplink" to (deepLink ?: ""),
                    "user_id" to userId,
                    // Só alimenta NotificationResult/listeners; não entra no payload do evento.
                    DitoNotificationActionReceiver.EXTRA_CUSTOM_DATA to
                        (intent?.getStringExtra(DitoNotificationActionReceiver.EXTRA_CUSTOM_DATA) ?: ""),
                )

                Dito.notificationClick(userInfo, Dito.notificationClickListener ?: Dito.options?.notificationClickListener)
                Log.d(TAG, "✅ Dito.notificationClick() called successfully")
            }
        } else {
            Log.w(TAG, "❌ Cannot call notificationClick: reference=$reference, notificationId=$notificationId")
        }

        getTargetIntent(deepLink)?.let { targetIntent ->
            try {
                startActivity(targetIntent)
            } catch (e: Exception) {
                Log.e(TAG, "Error starting activity: ${e.message}")
            }
        }

        finish()
    }

    /**
     * Fecha a notificação ao tocar em um botão — `setAutoCancel` só vale para o corpo da notificação.
     */
    private fun dismissNotification() {
        val systemNotificationId = intent?.getIntExtra(
            DitoNotificationActionReceiver.EXTRA_SYSTEM_NOTIFICATION_ID,
            0,
        ) ?: 0
        if (systemNotificationId == 0) return
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(systemNotificationId)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to dismiss notification: ${e.message}")
        }
    }

    /**
     * Dispara o broadcast do toque no botão, restrito ao próprio pacote. O
     * [DitoNotificationActionReceiver] (declarado no manifest do SDK) registra o clique; apps
     * integradores podem declarar o mesmo filtro para observar o evento.
     */
    private fun broadcastActionClick(
        actionId: String,
        notificationId: String,
        reference: String,
        link: String,
        userId: String,
    ) {
        val actionLabel = intent?.getStringExtra(DitoNotificationActionReceiver.EXTRA_ACTION_LABEL) ?: ""
        val customDataJson = intent?.getStringExtra(DitoNotificationActionReceiver.EXTRA_CUSTOM_DATA) ?: ""
        val broadcast = Intent(DitoNotificationActionReceiver.ACTION_NOTIFICATION_ACTION_CLICK).apply {
            setPackage(packageName)
            putExtra(DitoNotificationActionReceiver.EXTRA_ACTION_ID, actionId)
            putExtra(DitoNotificationActionReceiver.EXTRA_ACTION_LABEL, actionLabel)
            putExtra(DitoNotificationActionReceiver.EXTRA_NOTIFICATION, notificationId)
            putExtra(DitoNotificationActionReceiver.EXTRA_REFERENCE, reference)
            putExtra(DitoNotificationActionReceiver.EXTRA_USER_ID, userId)
            putExtra(DitoNotificationActionReceiver.EXTRA_LINK, link)
            putExtra(DitoNotificationActionReceiver.EXTRA_CUSTOM_DATA, customDataJson)
        }
        sendBroadcast(broadcast)
    }

    private fun getTargetIntent(deepLink: String?): Intent? {
        val intent = Dito.options?.contentIntent
            ?: packageManager?.getLaunchIntentForPackage(packageName)
        if (intent == null) return null

        intent.apply {
            putExtra(Dito.DITO_DEEP_LINK, deepLink)
            if (Dito.getHibridMode() == "ON") {
                addFlags(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY)
            } else {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }
        return intent
    }
}
