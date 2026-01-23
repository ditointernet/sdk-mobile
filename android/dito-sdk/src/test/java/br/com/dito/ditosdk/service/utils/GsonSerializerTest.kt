package br.com.dito.ditosdk.service.utils

import br.com.dito.ditosdk.CustomData
import br.com.dito.ditosdk.Event
import br.com.dito.ditosdk.Identify
import com.google.common.truth.Truth.assertThat
import com.google.gson.JsonObject
import org.junit.Test

class GsonSerializerTest {

    @Test
    fun `gson should serialize CustomData correctly`() {
        val customData = CustomData().apply {
            add("string", "value")
            add("int", 42)
            add("double", 3.14)
            add("boolean", true)
        }
        val serializer = customDataSerializer()
        val json = serializer.serialize(customData.params, Map::class.java, null)

        assertThat(json).isNotNull()
        assertThat(json.asJsonObject.get("string").asString).isEqualTo("value")
        assertThat(json.asJsonObject.get("int").asInt).isEqualTo(42)
        assertThat(json.asJsonObject.get("double").asDouble).isEqualTo(3.14)
        assertThat(json.asJsonObject.get("boolean").asBoolean).isTrue()
    }

    @Test
    fun `gson should serialize Identify with data`() {
        val customData = CustomData().apply {
            add("key", "value")
        }
        val identify = Identify("user123").apply {
            name = "John"
            email = "john@example.com"
            data = customData
        }
        val serializer = identifySerializer()
        val json = serializer.serialize(identify, Identify::class.java, null)

        assertThat(json).isNotNull()
        assertThat(json.asJsonObject.get("id").asString).isEqualTo("user123")
        assertThat(json.asJsonObject.get("name").asString).isEqualTo("John")
        assertThat(json.asJsonObject.get("email").asString).isEqualTo("john@example.com")
    }

    @Test
    fun `gson should serialize Event with data`() {
        val customData = CustomData().apply {
            add("product", "item")
        }
        val event = Event("purchase", revenue = 99.99).apply {
            data = customData
        }
        val serializer = eventSerializer()
        val json = serializer.serialize(event, Event::class.java, null)

        assertThat(json).isNotNull()
        assertThat(json.asJsonObject.get("action").asString).isEqualTo("purchase")
        assertThat(json.asJsonObject.get("revenue").asDouble).isEqualTo(99.99)
    }

    @Test
    fun `gson should serialize EventRequest`() {
        val event = Event("purchase")
        val eventRequest = EventRequest("apiKey", "secret", event)
        val serializer = eventRequestSerializer()
        val json = serializer.serialize(eventRequest, EventRequest::class.java, null)

        assertThat(json).isNotNull()
        assertThat(json.asJsonObject.get("platform_api_key").asString).isEqualTo("apiKey")
        assertThat(json.asJsonObject.get("sha1_signature").asString).isEqualTo("secret")
    }

    @Test
    fun `gson should handle null CustomData`() {
        val identify = Identify("user123").apply {
            data = null
        }
        val serializer = identifySerializer()
        val json = serializer.serialize(identify, Identify::class.java, null)

        assertThat(json).isNotNull()
        assertThat(json.asJsonObject.has("data")).isTrue()
    }

    @Test
    fun `gson function should return configured Gson instance`() {
        val gson = gson()

        assertThat(gson).isNotNull()
    }

    @Test
    fun `gson should serialize empty CustomData`() {
        val customData = CustomData()
        val serializer = customDataSerializer()
        val json = serializer.serialize(customData.params, Map::class.java, null)

        assertThat(json).isNotNull()
        assertThat(json.asJsonObject.size()).isEqualTo(0)
    }
}
