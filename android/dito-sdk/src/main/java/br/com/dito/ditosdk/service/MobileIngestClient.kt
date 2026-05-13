package br.com.dito.ditosdk.service

import com.connectrpc.extensions.GoogleJavaLiteProtobufStrategy
import com.connectrpc.getOrThrow
import com.connectrpc.impl.ProtocolClient
import com.connectrpc.okhttp.ConnectOkHttpClient
import kotlinx.coroutines.Dispatchers
import mobileingest.v1.Api
import mobileingest.v1.MobileIngestServiceClient
import okhttp3.OkHttpClient

private const val INGEST_BASE_URL = "https://ingest.dito.com.br/mobile"

internal class MobileIngestClient(
    authHeaders: Map<String, String>,
    private val httpClientBuilder: (OkHttpClient.Builder.() -> Unit)? = null,
) : MobileIngestClientInterface {

    private val generatedClient: mobileingest.v1.MobileIngestServiceClientInterface

    init {
        val okHttp = baseOkHttpClient.newBuilder()
            .addInterceptor { chain ->
                val req = chain.request().newBuilder().apply {
                    authHeaders.forEach { (k, v) -> header(k, v) }
                }.build()
                chain.proceed(req)
            }
            .apply { httpClientBuilder?.invoke(this) }
            .build()

        val protocolClient = ProtocolClient(
            httpClient = ConnectOkHttpClient(okHttp),
            com.connectrpc.ProtocolClientConfig(
                host = INGEST_BASE_URL,
                serializationStrategy = GoogleJavaLiteProtobufStrategy(),
                ioCoroutineContext = Dispatchers.IO,
            ),
        )
        generatedClient = MobileIngestServiceClient(protocolClient)
    }

    override suspend fun activity(request: Api.Request): Api.Response {
        val result = generatedClient.activity(request, emptyMap())
        return result.getOrThrow()
    }

    companion object {
        private val baseOkHttpClient: OkHttpClient by lazy {
            OkHttpClient.Builder()
                .apply { ConnectOkHttpClient.configureClient(this) }
                .build()
        }

        fun withLegacyAuth(
            platformApiKey: String,
            sha1Signature: String,
            bundleId: String,
            httpClientBuilder: (OkHttpClient.Builder.() -> Unit)? = null,
        ) = MobileIngestClient(
            mapOf("platform_api_key" to platformApiKey, "sha1_signature" to sha1Signature, "Bundle-Id" to bundleId),
            httpClientBuilder,
        )

        fun withXApiKey(
            xApiKey: String,
            bundleId: String,
            httpClientBuilder: (OkHttpClient.Builder.() -> Unit)? = null,
        ) = MobileIngestClient(
            mapOf("X-Api-Key" to xApiKey, "Bundle-Id" to bundleId),
            httpClientBuilder,
        )
    }
}
