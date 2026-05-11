package br.com.dito.ditosdk

import android.content.Context
import android.content.pm.PackageManager
import br.com.dito.ditosdk.notification.DitoNotificationOptions
import br.com.dito.ditosdk.notification.inbox.DitoNotificationInfo
import br.com.dito.ditosdk.offline.DitoDatabase
import br.com.dito.ditosdk.service.ActivityMapper
import br.com.dito.ditosdk.service.MobileIngestClient
import br.com.dito.ditosdk.service.MobileIngestClientInterface
import br.com.dito.ditosdk.tracking.Tracker
import br.com.dito.ditosdk.tracking.TrackerOffline
import br.com.dito.ditosdk.tracking.TrackerRetry
import br.com.dito.ditosdk.utils.DitoSDKUtils
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Ponto de entrada do SDK Dito. Inicialize com [init] antes de chamar métodos de tracking ou notificações.
 *
 * **Autenticação:** no manifest (`<application>`), use `meta-data` com `android:name` `br.com.dito.API_KEY` e,
 * opcionalmente, `br.com.dito.API_SECRET`. Se existirem **ambos** `API_KEY` e `API_SECRET`, o SDK usa o
 * modelo legado (assinatura SHA1). Se existir **apenas** `API_KEY` (sem `API_SECRET`), usa o modelo X-Api-Key;
 * o `Bundle-Id` enviado ao backend é o `packageName` do app. `br.com.dito.HIBRID_MODE` é opcional.
 */
object Dito {

    private lateinit var apiKey: String
    private lateinit var apiSecret: String
    private lateinit var hibridMode: String
    private lateinit var tracker: Tracker
    private lateinit var applicationContext: Context

    const val DITO_NOTIFICATION_ID = "br.com.dito.ditosdk.DITO_NOTIFICATION_ID"
    const val DITO_NOTIFICATION_REFERENCE = "br.com.dito.ditosdk.DITO_NOTIFICATION_REFERENCE"
    const val DITO_DEEP_LINK = "br.com.dito.ditosdk.DITO_DEEP_LINK"
    const val DITO_USER_ID = "br.com.dito.ditosdk.DITO_USER_ID"

    var options: Options? = null
    var notificationClickListener: ((String) -> Unit)? = null
    var notificationReceivedListener: ((Map<String, String>) -> Unit)? = null
    var notificationOptions: DitoNotificationOptions = DitoNotificationOptions()
        private set

    fun setNotificationOptions(options: DitoNotificationOptions) {
        notificationOptions = options
    }

    /**
     * Inicializa o SDK lendo `br.com.dito.API_KEY`, `br.com.dito.API_SECRET` (opcional) e
     * `br.com.dito.HIBRID_MODE` do AndroidManifest do app host.
     *
     * @param context Contexto da aplicação Android
     * @param options Configurações opcionais do SDK (debug, retry, etc.)
     */
    fun init(context: Context?, options: Options?) {
        this.options = options
        this.notificationClickListener = options?.notificationClickListener
        if (context == null) throw RuntimeException("Context is not available")
        this.applicationContext = context.applicationContext
        val meta = context.packageManager
            .getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
            .metaData
        val resolvedApiKey = meta?.getString("br.com.dito.API_KEY", "") ?: ""
        val resolvedApiSecret = meta?.getString("br.com.dito.API_SECRET", "") ?: ""
        val resolvedHibridMode = meta?.getString("br.com.dito.HIBRID_MODE", "OFF") ?: "OFF"
        when {
            resolvedApiKey.isNotEmpty() && resolvedApiSecret.isNotEmpty() ->
                configureTracker(context, options, resolvedApiKey, resolvedApiSecret, resolvedHibridMode)
            resolvedApiKey.isNotEmpty() ->
                configureTrackerXApiKey(context, options, resolvedApiKey, resolvedHibridMode)
            else ->
                throw RuntimeException("É preciso configurar API_KEY no AndroidManifest.")
        }
    }

    /**
     * Inicializa o SDK com credenciais passadas em código (ex.: Flutter/React Native).
     * Não exige `meta-data` no manifest para as chaves.
     *
     * Se [apiSecret] for vazio ou omitido, o SDK usa autenticação X-Api-Key com [apiKey] e
     * `context.packageName` como bundle. Caso contrário, usa o modelo legado
     * (`platform_api_key` + `sha1_signature` da secret).
     *
     * @param context Contexto da aplicação Android
     * @param apiKey Chave da plataforma ou, no fluxo novo, valor da X-Api-Key
     * @param apiSecret Secret do modelo legado; vazio ou omitido ativa o fluxo X-Api-Key
     * @param options Configurações opcionais do SDK
     */
    fun init(context: Context?, apiKey: String, apiSecret: String = "", options: Options? = null) {
        this.options = options
        this.notificationClickListener = options?.notificationClickListener
        if (context == null) throw RuntimeException("Context is not available")
        this.applicationContext = context.applicationContext
        val hibridMode = resolveHibridMode(context)
        if (apiSecret.isNotEmpty()) {
            configureTracker(context, options, apiKey, apiSecret, hibridMode)
        } else {
            configureTrackerXApiKey(context, options, apiKey, hibridMode)
        }
    }

    private fun resolveHibridMode(context: Context?): String {
        val appInfo = context?.packageManager?.getApplicationInfo(
            context.packageName,
            PackageManager.GET_META_DATA,
        )
        return appInfo?.metaData?.getString("br.com.dito.HIBRID_MODE", "OFF") ?: "OFF"
    }

    private fun configureTracker(
        context: Context,
        options: Options?,
        apiKey: String,
        apiSecret: String,
        hibridMode: String,
    ) {
        this.apiKey = apiKey
        this.apiSecret = apiSecret
        this.hibridMode = hibridMode
        if (apiKey.isEmpty() || apiSecret.isEmpty()) {
            throw RuntimeException("É preciso configurar API_KEY e API_SECRET no AndroidManifest.")
        }
        configureTracker(
            context,
            options,
            MobileIngestClient.withLegacyAuth(apiKey, DitoSDKUtils.SHA1(apiSecret), context.packageName, options?.httpClientBuilder),
        )
    }

    private fun configureTrackerXApiKey(context: Context, options: Options?, xApiKey: String, hibridMode: String) {
        if (xApiKey.isEmpty()) {
            throw RuntimeException("API_KEY é obrigatório.")
        }
        this.apiKey = xApiKey
        this.apiSecret = ""
        this.hibridMode = hibridMode
        configureTracker(
            context,
            options,
            MobileIngestClient.withXApiKey(xApiKey, context.packageName, options?.httpClientBuilder),
        )
    }

    private fun configureTracker(context: Context, options: Options?, client: MobileIngestClientInterface) {
        if (::tracker.isInitialized) tracker.close()
        val mapper = ActivityMapper(context)
        val trackerOffline = TrackerOffline(context)
        tracker = Tracker(trackerOffline, client, mapper, debug = options?.debug == true)
        val trackerRetry = TrackerRetry(tracker, trackerOffline, client, mapper, options?.retry ?: 5)
        tracker.setTrackerRetry(trackerRetry)
        trackerRetry.uploadEvents()
    }

    /**
     * Identifica o usuário no CRM Dito com parâmetros individuais.
     *
     * @param id Identificador único do usuário
     * @param name Nome (opcional)
     * @param email E-mail (opcional)
     * @param customData Dados customizados adicionais (opcional)
     */
    fun identify(id: String, name: String? = null, email: String? = null, customData: Map<String, Any>? = null) {
        tracker.identify(
            Identify(id).apply {
                this.name = name
                this.email = email
                this.data = convertCustomData(customData)
            },
            null,
        )
    }

    /**
     * Identifica o usuário no CRM Dito com um objeto [Identify].
     *
     * @param identify Objeto com dados do usuário
     * @param callback Callback opcional após a identificação
     * @deprecated Use [identify] com parâmetros nomeados para alinhar ao SDK iOS
     */
    @Deprecated(
        message = "Use identify(id:name:email:customData:) instead for consistency with iOS SDK",
        replaceWith = ReplaceWith("identify(id, identify.name, identify.email, identify.data?.toMap())"),
    )
    fun identify(identify: Identify?, callback: (() -> Unit)?) {
        identify?.let { tracker.identify(it, callback) }
    }

    /**
     * Registra um evento no CRM Dito com nome da ação e dados opcionais.
     *
     * @param action Nome da ação do evento
     * @param data Dados adicionais do evento (opcional)
     */
    fun track(action: String, data: Map<String, Any>? = null) {
        tracker.event(
            Event(action).apply { this.data = convertCustomData(data) },
        )
    }

    /**
     * Registra um evento no CRM Dito com um objeto [Event].
     *
     * @param event Objeto com dados do evento
     * @deprecated Use [track] com ação e mapa de dados para alinhar ao SDK iOS
     */
    @Deprecated(
        message = "Use track(action:data:) instead for consistency with iOS SDK",
        replaceWith = ReplaceWith("track(event.action, event.data?.toMap())"),
    )
    fun track(event: Event?) {
        event?.let { tracker.event(it) }
    }

    /**
     * Registra o token do dispositivo para push (Firebase).
     *
     * @param token Token FCM; se null ou vazio, não envia
     */
    fun registerDevice(token: String?) {
        if (!token.isNullOrEmpty()) tracker.registerToken(token)
    }

    /**
     * Remove o registro do token de push do dispositivo.
     *
     * @param token Token FCM; se null ou vazio, não envia
     */
    fun unregisterDevice(token: String?) {
        if (!token.isNullOrEmpty()) tracker.unregisterToken(token)
    }

    /**
     * Chamado quando a notificação chega (antes do clique). Envia o evento de leitura da notificação.
     *
     * @param userInfo Mapa com dados da notificação (deve incluir chaves `"notification"` e `"reference"`)
     */
    fun notificationClick(userInfo: Map<String, String>) {
        val data = DitoNotificationHandler.extractReadData(userInfo)
        if (data.reference.isEmpty() || data.notificationId.isEmpty()) return
        tracker.notificationClick(data.notificationId, data.reference, data.userId)
        CoroutineScope(Dispatchers.IO).launch {
            DitoDatabase.getInstance(applicationContext).ditoNotificationDao().markAsReadByNotificationId(data.notificationId)
        }
    }

    /**
     * Chamado quando a notificação é lida. Identifica o usuário (se houver `userId`) e traz o evento
     * `receive-android-notification`.
     *
     * @param userInfo Mapa com dados da notificação (deve incluir `"notification"` e `"reference"`)
     */
    fun notificationRead(userInfo: Map<String, String>) {
        val data = DitoNotificationHandler.extractReadData(userInfo)
        if (data.reference.isEmpty() || data.notificationId.isEmpty()) return
        processNotificationReceived(data)
    }

    /**
     * Processa a notificação recebida com dados já extraídos.
     *
     * @param data Dados estruturados da notificação
     */
    fun processNotificationReceived(data: NotificationReadData) {
        DitoNotificationHandler.processReceived(data, tracker)
    }

    /**
     * Chamado quando o usuário clica na notificação. Envia o evento de clique, chama o callback de deeplink
     * e retorna [NotificationResult] com os dados.
     *
     * @param userInfo Mapa com dados (inclua `"notification"`, `"reference"` e, se houver, `"deeplink"`)
     * @param callback Opcional; recebe a URL do deeplink
     * @return [NotificationResult] com id, reference e deepLink
     */
    fun notificationClick(userInfo: Map<String, String>, callback: ((String) -> Unit)? = null): NotificationResult {
        val result = DitoNotificationHandler.handleClick(userInfo, callback, tracker)
        if (result.notificationId.isNotEmpty()) {
            CoroutineScope(Dispatchers.IO).launch {
                DitoDatabase.getInstance(applicationContext).ditoNotificationDao().markAsReadByNotificationId(result.notificationId)
            }
        }
        return result
    }

    /**
     * Dados de uma notificação recebida/lida para processamento pelo SDK.
     */
    data class NotificationReadData(
        val notificationId: String,
        val reference: String,
        val logId: String,
        val notificationName: String,
        val userId: String,
    )

    suspend fun getNotifications(): List<DitoNotificationInfo> =
        DitoDatabase.getInstance(applicationContext).ditoNotificationDao().getAll().map { record ->
            DitoNotificationInfo(
                id = record.id,
                notificationId = record.notificationId,
                reference = record.reference,
                title = record.title,
                message = record.message,
                link = record.link,
                receivedAt = record.receivedAt,
                isRead = record.isRead,
            )
        }

    suspend fun markNotificationAsRead(id: String) {
        DitoDatabase.getInstance(applicationContext).ditoNotificationDao().markAsRead(id)
    }

    internal fun isInitialized(): Boolean =
        ::apiKey.isInitialized && apiKey.isNotEmpty() && ::apiSecret.isInitialized

    /**
     * Retorna o valor de `br.com.dito.HIBRID_MODE` usado na inicialização (default `"OFF"`).
     */
    fun getHibridMode(): String = hibridMode

    private fun convertCustomData(customData: Map<String, Any>?): CustomData? {
        if (customData == null) return null
        return CustomData().apply {
            customData.forEach { (key, value) ->
                when (value) {
                    is String -> add(key, value)
                    is Int -> add(key, value)
                    is Double -> add(key, value)
                    is Boolean -> add(key, value)
                    else -> params[key] = value
                }
            }
        }
    }
}
