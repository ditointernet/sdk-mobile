package br.com.dito.ditosdk.utils

import br.com.dito.ditosdk.utils.formatToISO
import com.google.common.truth.Truth.assertThat
import org.junit.Test
import java.text.SimpleDateFormat
import java.util.*

class DateExtensionTest {

    @Test
    fun `formatToISO should return correct ISO format`() {
        val date = Date(1609459200000L)
        val formatted = date.formatToISO()

        val expectedFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ", Locale.getDefault())
        val expected = expectedFormat.format(date)

        assertThat(formatted).isEqualTo(expected)
        assertThat(formatted).matches("\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}[+-]\\d{4}")
    }

    @Test
    fun `formatToISO should handle different dates`() {
        val date1 = Date(0L)
        val date2 = Date(System.currentTimeMillis())

        val formatted1 = date1.formatToISO()
        val formatted2 = date2.formatToISO()

        assertThat(formatted1).isNotEmpty()
        assertThat(formatted2).isNotEmpty()
        assertThat(formatted1).isNotEqualTo(formatted2)
    }

    @Test
    fun `formatToISO should include timezone offset`() {
        val date = Date()
        val formatted = date.formatToISO()

        assertThat(formatted).contains("T")
        assertThat(formatted.length).isAtLeast(20)
    }
}
