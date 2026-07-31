package br.com.dito.ditosdk.notification.inbox

data class DitoNotificationInfo(
    val id: String,
    val notificationId: String,
    val reference: String,
    val title: String,
    val message: String,
    val link: String,
    val receivedAt: Long,
    val isRead: Boolean,
    /** URL da imagem do push; vazio quando a campanha não tem imagem. */
    val image: String = "",
    /** Custom data da campanha já decodificada; vazia quando não há custom data. */
    val customData: Map<String, String> = emptyMap(),
)
