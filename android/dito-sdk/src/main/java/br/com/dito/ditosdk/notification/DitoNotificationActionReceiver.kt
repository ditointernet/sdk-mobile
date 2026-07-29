package br.com.dito.ditosdk.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import br.com.dito.ditosdk.Dito

/**
 * Recebe o toque em um botão de ação da notificação e registra o clique.
 *
 * O broadcast é disparado pela [NotificationOpenedActivity] — que é o alvo direto do `PendingIntent`
 * do botão — em vez de o botão apontar direto para este receiver. Isso é proposital: desde o
 * Android 12 um `BroadcastReceiver` acionado por notificação não pode iniciar Activities
 * ("notification trampoline"), então quem abre o link precisa ser a Activity. O receiver fica
 * responsável apenas pelo tracking, que não sofre essa restrição.
 *
 * O broadcast é restrito ao próprio pacote (`setPackage`), então apps integradores podem declarar
 * o mesmo `intent-filter` para observar o toque sem nenhuma configuração extra.
 */
class DitoNotificationActionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "DitoNotificationActionReceiver"

        const val ACTION_NOTIFICATION_ACTION_CLICK =
            "br.com.dito.ditosdk.notification.NOTIFICATION_ACTION_CLICK"

        const val EXTRA_ACTION_ID = "action_id"
        const val EXTRA_ACTION_LABEL = "action_label"
        const val EXTRA_NOTIFICATION = "notification"
        const val EXTRA_REFERENCE = "reference"
        const val EXTRA_USER_ID = "user_id"
        const val EXTRA_LINK = "link"

        /** Custom data da campanha, ainda como string JSON, repassada para os listeners. */
        const val EXTRA_CUSTOM_DATA = "custom_data"

        /** Id da notificação no NotificationManager, usado para fechá-la ao tocar em um botão. */
        internal const val EXTRA_SYSTEM_NOTIFICATION_ID =
            "br.com.dito.ditosdk.SYSTEM_NOTIFICATION_ID"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return
        if (intent.action != null && intent.action != ACTION_NOTIFICATION_ACTION_CLICK) {
            Log.w(TAG, "Ignoring unexpected action: ${intent.action}")
            return
        }

        val actionId = intent.getStringExtra(EXTRA_ACTION_ID) ?: ""
        val actionLabel = intent.getStringExtra(EXTRA_ACTION_LABEL) ?: ""
        val notificationId = intent.getStringExtra(EXTRA_NOTIFICATION) ?: ""
        val reference = intent.getStringExtra(EXTRA_REFERENCE) ?: ""
        val userId = intent.getStringExtra(EXTRA_USER_ID) ?: ""
        val link = intent.getStringExtra(EXTRA_LINK) ?: ""
        val customDataJson = intent.getStringExtra(EXTRA_CUSTOM_DATA) ?: ""

        Log.d(TAG, "Notification action clicked: id=$actionId, notification=$notificationId")

        if (notificationId.isEmpty() || reference.isEmpty()) {
            Log.w(TAG, "Missing notification/reference; skipping click tracking")
            return
        }

        try {
            if (!Dito.isInitialized()) {
                Dito.init(context.applicationContext, null)
            }
            Dito.notificationClick(
                mapOf(
                    "notification" to notificationId,
                    "reference" to reference,
                    "deeplink" to link,
                    "user_id" to userId,
                    EXTRA_ACTION_ID to actionId,
                    EXTRA_ACTION_LABEL to actionLabel,
                    EXTRA_CUSTOM_DATA to customDataJson,
                ),
                Dito.notificationClickListener ?: Dito.options?.notificationClickListener,
            )
        } catch (e: Exception) {
            Log.w(TAG, "Failed to track notification action click: ${e.message}")
        }
    }
}
