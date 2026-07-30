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

        val click = NotificationClickExtras.from(intent)

        Log.d(TAG, "Notification ID: ${click.notificationId}")
        Log.d(TAG, "Reference: ${click.reference}")
        Log.d(TAG, "Deep Link: ${click.deepLink}")

        if (!Dito.isInitialized()) {
            Log.d(TAG, "Dito not initialized, initializing...")
            // `init` **lança** quando o app não declara `br.com.dito.API_KEY` no manifest, e
            // é exatamente o caso de quem inicializa por código — Flutter e React Native
            // passam as credenciais em `Dito.init(context, apiKey, secret)`. Sem este catch,
            // todo toque em notificação depois da morte do processo derrubava o app aqui.
            // Abrir o app é mais importante que registrar o clique.
            try {
                Dito.init(applicationContext, null)
            } catch (e: Exception) {
                Log.w(TAG, "Could not initialize Dito on click: ${e.message}")
            }
        }

        if (click.isActionClick) {
            dismissNotification()
        }

        // Só `notificationId` é obrigatório. `reference` está em retirada dos payloads da
        // Dito e a atribuição ancora em `user_id`; exigi-lo aqui descartava **todo** clique
        // de campanha sem o campo, no corpo e no botão, sem nada além de um warning no
        // logcat. Reproduzido no emulador: "❌ Cannot call notificationClick: reference=,
        // notificationId=case5-notification", com o broadcast do botão também engolido.
        if (click.notificationId.isNotEmpty()) {
            if (click.isActionClick) {
                Log.d(TAG, "✅ Broadcasting notification action click: ${click.actionId}")
                broadcastActionClick(click)
            } else {
                Log.d(TAG, "✅ Calling Dito.notificationClick()")
                Dito.notificationClick(
                    click.toUserInfo(),
                    Dito.notificationClickListener ?: Dito.options?.notificationClickListener,
                )
                Log.d(TAG, "✅ Dito.notificationClick() called successfully")
            }
        } else {
            Log.w(TAG, "❌ Cannot call notificationClick: notificationId vazio")
        }

        getTargetIntent(click)?.let { targetIntent ->
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
    private fun broadcastActionClick(click: NotificationClickExtras) {
        val broadcast = Intent(DitoNotificationActionReceiver.ACTION_NOTIFICATION_ACTION_CLICK).apply {
            setPackage(packageName)
            putExtra(DitoNotificationActionReceiver.EXTRA_ACTION_ID, click.actionId)
            putExtra(DitoNotificationActionReceiver.EXTRA_ACTION_LABEL, click.actionLabel)
            putExtra(DitoNotificationActionReceiver.EXTRA_NOTIFICATION, click.notificationId)
            putExtra(DitoNotificationActionReceiver.EXTRA_REFERENCE, click.reference)
            putExtra(DitoNotificationActionReceiver.EXTRA_USER_ID, click.userId)
            putExtra(DitoNotificationActionReceiver.EXTRA_LINK, click.deepLink)
            putExtra(DitoNotificationActionReceiver.EXTRA_CUSTOM_DATA, click.customDataJson)
        }
        sendBroadcast(broadcast)
    }

    /**
     * Monta o Intent que abre o app. **Não abre link** — nem o deeplink da notificação, nem o link
     * do botão, nem uma URL externa: o toque inteiro viaja como extras (ver
     * [NotificationClickExtras]) e quem decide o que fazer é o app.
     *
     * O `contentIntent` configurado é **copiado** antes de receber os extras. Sem a cópia, os
     * extras eram gravados no objeto que o app registrou uma única vez, então um toque em botão
     * deixava `actionId` grudado ali para todos os cliques seguintes.
     */
    private fun getTargetIntent(click: NotificationClickExtras): Intent? {
        val configured = Dito.options?.contentIntent
        val intent = if (configured != null) {
            Intent(configured)
        } else {
            packageManager?.getLaunchIntentForPackage(packageName)
        }
        if (intent == null) return null

        click.writeTo(intent)
        if (Dito.getHibridMode() == "ON") {
            intent.addFlags(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY)
        } else {
            intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return intent
    }
}
