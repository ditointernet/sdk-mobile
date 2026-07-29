package br.com.dito.ditosdk

import android.content.Intent
import androidx.annotation.IdRes
import br.com.dito.ditosdk.utils.formatToISO
import java.util.Date
import okhttp3.OkHttpClient

data class Options(
    val retry: Int = 5,
    val httpClientBuilder: (OkHttpClient.Builder.() -> Unit)? = null,
) {
    var contentIntent: Intent? = null
    var notificationClickListener: ((String) -> Unit)? = null

    @Deprecated(
        message = "Use Dito.setNotificationOptions(DitoNotificationOptions(smallIconResId = ...)) instead",
        replaceWith = ReplaceWith(
            expression = "Dito.setNotificationOptions(DitoNotificationOptions(smallIconResId = iconNotification))",
            imports = [
                "br.com.dito.ditosdk.Dito",
                "br.com.dito.ditosdk.notification.DitoNotificationOptions",
            ]
        )
    )
    @IdRes
    var iconNotification: Int? = null
    var debug: Boolean = false
}

data class Identify(val id: String) {
    var name: String? = null
    var email: String? = null
    var gender: String? = null
    var location: String? = null
    var birthday: String? = null
    var createdAt: String? = Date().formatToISO()
    var data: CustomData? = null
}

data class Event(val action: String, val revenue: Double? = null) {
    var createdAt: String? = Date().formatToISO()
    var data: CustomData? = null
}

internal data class EventOff(
    val id: Int,
    val activityId: String,
    val action: String,
    val revenue: Float?,
    val dataJson: String?,
    val timestamp: String,
    val retry: Int,
)

internal data class IdentifyOff(
    val id: String,
    val name: String?,
    val email: String?,
    val gender: String?,
    val birthday: String?,
    val location: String?,
    val customDataJson: String?,
    val send: Boolean,
)

internal data class NotificationReadOff(
    val id: Int,
    val activityId: String,
    val notificationId: String,
    val identifier: String,
    val retry: Int,
)

data class NotificationResult(
    val notificationId: String,
    val reference: String,
    val deepLink: String,
    /** Id do botão tocado; vazio quando o clique foi no corpo da notificação. */
    val actionId: String = "",
    /** Label do botão tocado; vazio quando o clique foi no corpo da notificação. */
    val actionLabel: String = "",
    /** Custom data da campanha já decodificada; vazia quando a campanha não tem custom data. */
    val customData: Map<String, String> = emptyMap(),
)
