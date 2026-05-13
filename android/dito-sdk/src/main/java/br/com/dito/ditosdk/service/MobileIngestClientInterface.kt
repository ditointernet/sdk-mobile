package br.com.dito.ditosdk.service

import mobileingest.v1.Api

internal interface MobileIngestClientInterface {
    suspend fun activity(request: Api.Request): Api.Response
}
