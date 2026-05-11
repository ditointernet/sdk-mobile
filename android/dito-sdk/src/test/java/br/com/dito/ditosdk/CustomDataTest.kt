package br.com.dito.ditosdk

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.service.ActivityMapper
import com.google.common.truth.Truth.assertThat
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class CustomDataTest {

    private lateinit var context: Context
    private lateinit var mapper: ActivityMapper

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        mapper = ActivityMapper(context)
    }

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

    @Test
    fun mapToProto_withStringValue_setsStringSingle() {
        // Arrange
        val cd = CustomData().apply { add("k", "v") }

        // Act
        val result = mapper.customDataToProto(cd)

        // Assert
        assertThat(result["k"]?.single?.stringValue).isEqualTo("v")
        assertThat(result["k"]?.hasSingle()).isTrue()
    }

    @Test
    fun mapToProto_withDoubleValue_setsNumberSingle() {
        // Arrange
        val cd = CustomData().apply { add("k", 3.14) }

        // Act
        val result = mapper.customDataToProto(cd)

        // Assert
        assertThat(result["k"]?.single?.numberValue).isEqualTo(3.14)
    }

    @Test
    fun mapToProto_withIntValue_setsNumberSingle() {
        // Arrange
        val cd = CustomData().apply { add("k", 42) }

        // Act
        val result = mapper.customDataToProto(cd)

        // Assert
        assertThat(result["k"]?.single?.numberValue).isEqualTo(42.0)
    }

    @Test
    fun mapToProto_withBoolValue_setsBoolSingle() {
        // Arrange
        val cd = CustomData().apply { add("k", true) }

        // Act
        val result = mapper.customDataToProto(cd)

        // Assert
        assertThat(result["k"]?.single?.boolValue).isTrue()
    }

    @Test
    fun mapToProto_withNullCustomData_returnsEmptyMap() {
        // Arrange + Act
        val result = mapper.customDataToProto(null)

        // Assert
        assertThat(result).isEmpty()
    }

    @Test
    fun mapToProto_withMixedTypes_mapsAllCorrectly() {
        // Arrange
        val cd = CustomData().apply {
            add("str", "hello")
            add("num", 2.71)
            add("flag", false)
        }

        // Act
        val result = mapper.customDataToProto(cd)

        // Assert
        assertThat(result["str"]?.single?.stringValue).isEqualTo("hello")
        assertThat(result["num"]?.single?.numberValue).isEqualTo(2.71)
        assertThat(result["flag"]?.single?.boolValue).isFalse()
    }
}
