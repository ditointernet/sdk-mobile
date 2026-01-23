package br.com.dito.ditosdk

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class CustomDataTest {

    @Test
    fun `add String value should store in params`() {
        val customData = CustomData()
        customData.add("key1", "value1")

        assertThat(customData.params["key1"]).isEqualTo("value1")
    }

    @Test
    fun `add Int value should store in params`() {
        val customData = CustomData()
        customData.add("key2", 42)

        assertThat(customData.params["key2"]).isEqualTo(42)
    }

    @Test
    fun `add Double value should store in params`() {
        val customData = CustomData()
        customData.add("key3", 3.14)

        assertThat(customData.params["key3"]).isEqualTo(3.14)
    }

    @Test
    fun `add Boolean value should store in params`() {
        val customData = CustomData()
        customData.add("key4", true)

        assertThat(customData.params["key4"]).isEqualTo(true)
    }

    @Test
    fun `add multiple values should store all in params`() {
        val customData = CustomData()
        customData.add("string", "test")
        customData.add("int", 100)
        customData.add("double", 2.5)
        customData.add("boolean", false)

        assertThat(customData.params.size).isEqualTo(4)
        assertThat(customData.params["string"]).isEqualTo("test")
        assertThat(customData.params["int"]).isEqualTo(100)
        assertThat(customData.params["double"]).isEqualTo(2.5)
        assertThat(customData.params["boolean"]).isEqualTo(false)
    }

    @Test
    fun `overwrite existing key should replace value`() {
        val customData = CustomData()
        customData.add("key", "original")
        customData.add("key", "updated")

        assertThat(customData.params["key"]).isEqualTo("updated")
        assertThat(customData.params.size).isEqualTo(1)
    }
}
