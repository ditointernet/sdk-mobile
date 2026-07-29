package br.com.dito.ditosdk.notification

import android.content.Intent
import br.com.dito.ditosdk.Dito

/**
 * Tudo o que um toque em notificação carrega, seja no corpo ou em um botão.
 *
 * Existe porque o SDK **não abre link nenhum**: nem o deeplink principal, nem o link de um botão,
 * nem uma URL externa. O que ele faz é abrir o app (o `contentIntent` configurado, ou a launch
 * activity) e entregar o toque inteiro como extras desse Intent — o roteamento é decisão do app.
 * O mesmo vale no iOS, onde o `notificationClick(response:)` devolve os dados e chama o callback
 * com o link, sem abrir nada.
 *
 * Os campos são sempre escritos, inclusive vazios, para que um toque no corpo não herde o
 * `actionId` de um toque em botão anterior — o `contentIntent` é um objeto só, reaproveitado a
 * cada clique.
 */
internal data class NotificationClickExtras(
    val notificationId: String,
    val reference: String,
    val deepLink: String,
    val userId: String,
    val actionId: String,
    val actionLabel: String,
    val customDataJson: String,
) {

    /** `true` quando o toque veio de um botão de ação, e não do corpo da notificação. */
    val isActionClick: Boolean get() = actionId.isNotEmpty()

    fun writeTo(target: Intent): Intent = target.apply {
        putExtra(Dito.DITO_NOTIFICATION_ID, notificationId)
        putExtra(Dito.DITO_NOTIFICATION_REFERENCE, reference)
        putExtra(Dito.DITO_DEEP_LINK, deepLink)
        putExtra(Dito.DITO_USER_ID, userId)
        putExtra(Dito.DITO_ACTION_ID, actionId)
        putExtra(Dito.DITO_ACTION_LABEL, actionLabel)
        putExtra(Dito.DITO_CUSTOM_DATA, customDataJson)
    }

    /**
     * Payload no formato que [Dito.notificationClick] espera. As chaves são as do payload FCM
     * (`notification`, `reference`, `deeplink`), não as constantes de Intent.
     */
    fun toUserInfo(): Map<String, String> = buildMap {
        put("notification", notificationId)
        put("reference", reference)
        put("deeplink", deepLink)
        put("user_id", userId)
        put(DitoNotificationActionReceiver.EXTRA_CUSTOM_DATA, customDataJson)
        if (isActionClick) {
            put(DitoNotificationActionReceiver.EXTRA_ACTION_ID, actionId)
            put(DitoNotificationActionReceiver.EXTRA_ACTION_LABEL, actionLabel)
        }
    }

    companion object {

        /**
         * Lê o toque do Intent que abriu a [NotificationOpenedActivity], aceitando tanto as
         * constantes do SDK quanto as chaves cruas do payload FCM — o clique no corpo pode chegar
         * pelos dois caminhos, dependendo de quem montou o `PendingIntent`.
         */
        fun from(intent: Intent?): NotificationClickExtras {
            if (intent == null) return empty()
            return NotificationClickExtras(
                notificationId = intent.firstNonEmpty(Dito.DITO_NOTIFICATION_ID, "notification"),
                reference = intent.firstNonEmpty(Dito.DITO_NOTIFICATION_REFERENCE, "reference"),
                deepLink = intent.firstNonEmpty(Dito.DITO_DEEP_LINK, "link"),
                userId = intent.firstNonEmpty(Dito.DITO_USER_ID, "user_id"),
                actionId = intent.firstNonEmpty(
                    DitoNotificationActionReceiver.EXTRA_ACTION_ID,
                    Dito.DITO_ACTION_ID,
                ),
                actionLabel = intent.firstNonEmpty(
                    DitoNotificationActionReceiver.EXTRA_ACTION_LABEL,
                    Dito.DITO_ACTION_LABEL,
                ),
                customDataJson = intent.firstNonEmpty(
                    DitoNotificationActionReceiver.EXTRA_CUSTOM_DATA,
                    Dito.DITO_CUSTOM_DATA,
                ),
            )
        }

        private fun empty() = NotificationClickExtras("", "", "", "", "", "", "")

        private fun Intent.firstNonEmpty(vararg keys: String): String {
            for (key in keys) {
                val value = getStringExtra(key)
                if (!value.isNullOrEmpty()) return value
            }
            return ""
        }
    }
}
