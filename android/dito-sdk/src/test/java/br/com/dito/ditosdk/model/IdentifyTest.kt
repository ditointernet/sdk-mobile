package br.com.dito.ditosdk.model

import br.com.dito.ditosdk.CustomData
import br.com.dito.ditosdk.Identify
import com.google.common.truth.Truth.assertThat
import org.junit.Test

class IdentifyTest {

    @Test
    fun `Identify should require id parameter`() {
        val identify = Identify("user123")

        assertThat(identify.id).isEqualTo("user123")
    }

    @Test
    fun `Identify should have nullable name`() {
        val identify = Identify("user123")

        assertThat(identify.name).isNull()
    }

    @Test
    fun `Identify should set name`() {
        val identify = Identify("user123").apply {
            name = "John Doe"
        }

        assertThat(identify.name).isEqualTo("John Doe")
    }

    @Test
    fun `Identify should have nullable email`() {
        val identify = Identify("user123")

        assertThat(identify.email).isNull()
    }

    @Test
    fun `Identify should set email`() {
        val identify = Identify("user123").apply {
            email = "john@example.com"
        }

        assertThat(identify.email).isEqualTo("john@example.com")
    }

    @Test
    fun `Identify should have nullable data`() {
        val identify = Identify("user123")

        assertThat(identify.data).isNull()
    }

    @Test
    fun `Identify should set customData`() {
        val customData = CustomData().apply {
            add("key", "value")
        }
        val identify = Identify("user123").apply {
            data = customData
        }

        assertThat(identify.data).isNotNull()
        assertThat(identify.data?.params?.get("key")).isEqualTo("value")
    }

    @Test
    fun `Identify should have createdAt set automatically`() {
        val identify = Identify("user123")

        assertThat(identify.createdAt).isNotNull()
        assertThat(identify.createdAt).isNotEmpty()
    }

    @Test
    fun `Identify should allow setting createdAt`() {
        val customDate = "2023-01-01T00:00:00+0000"
        val identify = Identify("user123").apply {
            createdAt = customDate
        }

        assertThat(identify.createdAt).isEqualTo(customDate)
    }
}
