package br.com.dito.ditosdk.notification

import android.content.ActivityNotFoundException
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

        if (reference != null && notificationId != null) {
            Log.d(TAG, "✅ Calling Dito.notificationClick()")
            val userInfo = mapOf(
                "notification" to notificationId,
                "reference" to reference,
                "deeplink" to (deepLink ?: "")
            )

            Dito.notificationClick(userInfo, Dito.notificationClickListener ?: Dito.options?.notificationClickListener)
            Log.d(TAG, "✅ Dito.notificationClick() called successfully")
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
