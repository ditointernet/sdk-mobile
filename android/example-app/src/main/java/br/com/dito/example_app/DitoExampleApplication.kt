package br.com.dito.example_app

import android.R
import android.app.Application
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import br.com.dito.ditosdk.Dito
import br.com.dito.ditosdk.Options
import br.com.dito.ditosdk.notification.DitoMessagingService
import br.com.dito.ditosdk.notification.NotificationInterceptor
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.RemoteMessage

class DitoExampleApplication : Application() {

    companion object {
        private const val TAG = "DitoExample"

        /** O data map do push pode trazer credenciais; valor mascarado antes de ir para o logcat. */
        private val MASKED_KEYS = setOf("api_key", "api_secret", "secret")
    }

    @RequiresApi(Build.VERSION_CODES.O)
    override fun onCreate() {
        super.onCreate()

        try {
            FirebaseApp.initializeApp(this)
            Log.d("DitoExample", "Firebase inicializado com sucesso")
        } catch (e: Exception) {
            Log.e("DitoExample", "Erro ao inicializar Firebase: ${e.message}", e)
        }

        try {
            val options = Options(retry = 5)
            options.debug = true
            R.drawable.ic_dialog_info.also { options.iconNotification = it }
            Dito.init(this, options)
            Log.d("DitoExample", "Dito SDK inicializado com sucesso")
        } catch (e: Exception) {
            Log.e("DitoExample", "Erro ao inicializar Dito SDK: ${e.message}", e)
        }

        setupNotificationCallbacks()
        setupNotificationInterceptor()
    }

    /**
     * Registro **depois** de `Dito.init`: `init` com `Options` não-nulo sobrescreve
     * `notificationClickListener` com o campo homônimo de `Options` (que aqui é nulo), então
     * registrar antes apagaria o listener. Cada callback emite uma linha única com prefixo fixo
     * para que um teste em dispositivo possa provar, via logcat, que o payload do toque chega
     * inteiro ao app host.
     */
    private fun setupNotificationCallbacks() {
        Dito.notificationClickDataListener = { result ->
            Log.i(
                TAG,
                "DITO_CB_CLICK_DATA notificationId=${oneLine(result.notificationId)} " +
                    "reference=${oneLine(result.reference)} " +
                    "deepLink=${oneLine(result.deepLink)} " +
                    "actionId=${oneLine(result.actionId)} " +
                    "actionLabel=${oneLine(result.actionLabel)} " +
                    "customDataKeys=${result.customData.keys.sorted()} " +
                    "customData={${flatten(result.customData)}}",
            )
        }

        Dito.notificationClickListener = { deepLink ->
            Log.i(TAG, "DITO_CB_CLICK_LINK deepLink=${oneLine(deepLink)}")
        }

        Dito.notificationReceivedListener = { data ->
            Log.i(
                TAG,
                "DITO_CB_RECEIVED dataKeys=${data.keys.sorted()} " +
                    "data={${flatten(data, mask = true)}}",
            )
        }
    }

    private fun setupNotificationInterceptor() {
        DitoMessagingService.notificationInterceptor = object : NotificationInterceptor {
            override fun onNotificationReceived(remoteMessage: RemoteMessage) {
                Log.d("DitoExample", "Interceptando notificação para debug")
                NotificationDebugHelper.saveNotificationPayload(applicationContext, remoteMessage)
            }
        }
    }

    /** Um marcador é uma linha só: um `\n` no valor quebraria o grep do teste em duas. */
    private fun oneLine(value: String): String = value.replace("\n", "\\n").replace("\r", "\\r")

    private fun flatten(map: Map<String, String>, mask: Boolean = false): String =
        map.entries.sortedBy { it.key }.joinToString(separator = "&") { (key, value) ->
            "$key=${if (mask && key.lowercase() in MASKED_KEYS) "***" else oneLine(value)}"
        }
}
