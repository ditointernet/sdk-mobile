package br.com.dito.ditosdk.model

import br.com.dito.ditosdk.Options
import com.google.common.truth.Truth.assertThat
import org.junit.Test

class OptionsTest {

    @Test
    fun `Options should have default retry value`() {
        val options = Options()

        assertThat(options.retry).isEqualTo(5)
    }

    @Test
    fun `Options should accept custom retry value`() {
        val options = Options(retry = 10)

        assertThat(options.retry).isEqualTo(10)
    }

    @Test
    fun `Options should have nullable contentIntent`() {
        val options = Options()

        assertThat(options.contentIntent).isNull()
    }

    @Test
    fun `Options should have nullable iconNotification`() {
        val options = Options()

        assertThat(options.iconNotification).isNull()
    }

    @Test
    fun `Options should have default debug value`() {
        val options = Options()

        assertThat(options.debug).isFalse()
    }

    @Test
    fun `Options should accept custom debug value`() {
        val options = Options(debug = true)

        assertThat(options.debug).isTrue()
    }
}
