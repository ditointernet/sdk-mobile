package br.com.dito.ditosdk.model

import br.com.dito.ditosdk.CustomData
import br.com.dito.ditosdk.Event
import com.google.common.truth.Truth.assertThat
import org.junit.Test

class EventTest {

    @Test
    fun `Event should require action parameter`() {
        val event = Event("purchase")

        assertThat(event.action).isEqualTo("purchase")
    }

    @Test
    fun `Event should have nullable revenue`() {
        val event = Event("purchase")

        assertThat(event.revenue).isNull()
    }

    @Test
    fun `Event should accept revenue parameter`() {
        val event = Event("purchase", revenue = 99.99)

        assertThat(event.revenue).isEqualTo(99.99)
    }

    @Test
    fun `Event should have nullable data`() {
        val event = Event("purchase")

        assertThat(event.data).isNull()
    }

    @Test
    fun `Event should set customData`() {
        val customData = CustomData().apply {
            add("product_id", "123")
        }
        val event = Event("purchase").apply {
            data = customData
        }

        assertThat(event.data).isNotNull()
        assertThat(event.data?.params["product_id"]).isEqualTo("123")
    }

    @Test
    fun `Event should have createdAt set automatically`() {
        val event = Event("purchase")

        assertThat(event.createdAt).isNotNull()
        assertThat(event.createdAt).isNotEmpty()
    }

    @Test
    fun `Event should allow setting createdAt`() {
        val customDate = "2023-01-01T00:00:00+0000"
        val event = Event("purchase").apply {
            createdAt = customDate
        }

        assertThat(event.createdAt).isEqualTo(customDate)
    }
}
