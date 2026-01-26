package br.com.dito.example_app

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
            options.iconNotification = android.R.drawable.ic_dialog_info
            Dito.init(this, options)
            Log.d("DitoExample", "Dito SDK inicializado com sucesso")
        } catch (e: Exception) {
            Log.e("DitoExample", "Erro ao inicializar Dito SDK: ${e.message}", e)
        }

        setupNotificationInterceptor()
    }

    private fun setupNotificationInterceptor() {
        DitoMessagingService.notificationInterceptor = object : NotificationInterceptor {
            override fun onNotificationReceived(remoteMessage: RemoteMessage) {
                Log.d("DitoExample", "Interceptando notificação para debug")
                NotificationDebugHelper.saveNotificationPayload(applicationContext, remoteMessage)
            }
        }
    }
}
