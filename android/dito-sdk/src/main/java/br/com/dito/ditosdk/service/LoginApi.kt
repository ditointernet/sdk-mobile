package br.com.dito.ditosdk.service

import br.com.dito.ditosdk.service.utils.SigunpRequest
import com.google.gson.JsonObject
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.POST
import retrofit2.http.Path

internal interface LoginApi {
    @POST("/users/{network}/{id}/signup")
    suspend fun signup(@Path("network") network: String,
               @Path("id") id: String, @Body data: SigunpRequest)
            : Response<JsonObject>

    @POST("/users/{network}/{id}/signup")
    suspend fun signup(@Path("network") network: String,
               @Path("id") id: String, @Body data: JsonObject)
            : Response<JsonObject>
}