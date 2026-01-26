package br.com.dito.ditosdk.service

import br.com.dito.ditosdk.service.utils.EventRequest
import com.google.gson.JsonObject
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.POST
import retrofit2.http.Path

internal interface EventApi {
    @POST("/users/{id}")
    suspend fun track(@Path("id") id: String, @Body data: EventRequest)
            : Response<JsonObject>

    @POST("/users/{id}")
    suspend fun track(@Path("id") id: String, @Body data: JsonObject)
            : Response<JsonObject>
}