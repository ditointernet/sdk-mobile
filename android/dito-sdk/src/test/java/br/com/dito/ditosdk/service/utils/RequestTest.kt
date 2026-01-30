package br.com.dito.ditosdk.service.utils

import br.com.dito.ditosdk.Event
import br.com.dito.ditosdk.Identify
import com.google.common.truth.Truth.assertThat
import com.google.gson.JsonObject
import org.junit.Test

class RequestTest {

    @Test
    fun `SigunpRequest should have correct default encoding`() {
        val identify = Identify("user123")
        val request = SigunpRequest("apiKey", "secret", identify)

        assertThat(request.encoding).isEqualTo("base64")
    }

    @Test
    fun `SigunpRequest should store platformAppKey`() {
        val identify = Identify("user123")
        val request = SigunpRequest("apiKey", "secret", identify)

        assertThat(request.platformAppKey).isEqualTo("apiKey")
    }

    @Test
    fun `SigunpRequest should store sha1Signature`() {
        val identify = Identify("user123")
        val request = SigunpRequest("apiKey", "secret", identify)

        assertThat(request.sha1Signature).isEqualTo("secret")
    }

    @Test
    fun `SigunpRequest should store userData`() {
        val identify = Identify("user123")
        val request = SigunpRequest("apiKey", "secret", identify)

        assertThat(request.userData.id).isEqualTo("user123")
    }

    @Test
    fun `EventRequest should have correct default values`() {
        val event = Event("purchase")
        val request = EventRequest("apiKey", "secret", event)

        assertThat(request.encoding).isEqualTo("base64")
        assertThat(request.idType).isEqualTo("id")
        assertThat(request.networkName).isEqualTo("pt")
    }

    @Test
    fun `EventRequest should store event`() {
        val event = Event("purchase")
        val request = EventRequest("apiKey", "secret", event)

        assertThat(request.event.action).isEqualTo("purchase")
    }

    @Test
    fun `TokenRequest should have correct default values`() {
        val request = TokenRequest("apiKey", "secret", "token123")

        assertThat(request.encoding).isEqualTo("base64")
        assertThat(request.platform).isEqualTo("Android")
        assertThat(request.idType).isEqualTo("id")
    }

    @Test
    fun `TokenRequest should store token`() {
        val request = TokenRequest("apiKey", "secret", "token123")

        assertThat(request.token).isEqualTo("token123")
    }

    @Test
    fun `NotificationOpenRequest should have correct default values`() {
        val data = JsonObject()
        val request = NotificationOpenRequest("apiKey", "secret", data)

        assertThat(request.encoding).isEqualTo("base64")
        assertThat(request.channelType).isEqualTo("mobile")
    }

    @Test
    fun `NotificationOpenRequest should store data`() {
        val data = JsonObject().apply {
            addProperty("key", "value")
        }
        val request = NotificationOpenRequest("apiKey", "secret", data)

        assertThat(request.data.get("key").asString).isEqualTo("value")
    }
}
