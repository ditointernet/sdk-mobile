package br.com.dito.ditosdk.integration

import br.com.dito.ditosdk.BuildConfig

/**
 * Credenciais de integração materializadas em [BuildConfig] pelo build type `prodTest`.
 *
 * - **Legado:** `DITO_TEST_API_KEY` e `DITO_TEST_API_SECRET` no ambiente de build; se [API_SECRET] (após trim)
 *   não for vazio, os testes usam [API_KEY] + secret em [Dito.init].
 * **Solo (X-Api-Key):** se o secret (após trim) estiver vazio, os testes usam apenas [X_API_KEY] de
 * `DITO_TEST_X_API_KEY`, com secret vazio em [Dito.init].
 */
internal object TestConfig {
    const val PROD_BASE_URL = "https://ingest.dito.com.br/mobile"

    val API_KEY: String
        get() = BuildConfig.TEST_API_KEY

    val API_SECRET: String
        get() = BuildConfig.TEST_API_SECRET

    val X_API_KEY: String
        get() = BuildConfig.TEST_X_API_KEY
}
