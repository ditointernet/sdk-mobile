package br.com.dito.ditosdk.service

import br.com.dito.ditosdk.service.utils.NotificationOpenRequest
import br.com.dito.ditosdk.service.utils.TokenRequest
import com.google.gson.JsonObject
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.POST
import retrofit2.http.Path

internal interface NotificationApi {
    @POST("/users/{id}/mobile-tokens/")
    suspend fun add(@Path("id") id: String, @Body data: TokenRequest)
            : Response<JsonObject>


    @POST("/users/{id}/mobile-tokens/disable/")
    suspend fun disable(@Path("id") id: String, @Body data: TokenRequest)
            : Response<JsonObject>

    @POST("/notifications/{id}/open/")
    suspend fun open(@Path("id") id:String, @Body data: NotificationOpenRequest)
            : Response<JsonObject>

    @POST("/notifications/{id}/open/")
    suspend fun open(@Path("id") id:String, @Body data: JsonObject)
            : Response<JsonObject>
}