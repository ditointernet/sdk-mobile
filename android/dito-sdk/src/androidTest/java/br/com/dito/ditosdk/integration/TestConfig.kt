package br.com.dito.ditosdk.integration

import br.com.dito.ditosdk.BuildConfig

internal object TestConfig {
    const val PROD_BASE_URL = "https://ingest.dito.com.br/mobile"
    val API_KEY: String get() = BuildConfig.TEST_API_KEY
    val API_SECRET: String get() = BuildConfig.TEST_API_SECRET
}
