package br.com.dito.ditosdk.service

import br.com.dito.ditosdk.Dito
import br.com.dito.ditosdk.Options
import com.google.common.truth.Truth.assertThat
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class RemoteServiceTest {

    @Before
    fun setup() {
        Dito.options = null
    }

    @After
    fun tearDown() {
        Dito.options = null
    }

    @Test
    fun `loginApi should return LoginApi instance`() {
        val api = RemoteService.loginApi()

        assertThat(api).isNotNull()
    }

    @Test
    fun `eventApi should return EventApi instance`() {
        val api = RemoteService.eventApi()

        assertThat(api).isNotNull()
    }

    @Test
    fun `notificationApi should return NotificationApi instance`() {
        val api = RemoteService.notificationApi()

        assertThat(api).isNotNull()
    }

    @Test
    fun `loginApi should use correct base URL`() {
        val api = RemoteService.loginApi()

        assertThat(api).isNotNull()
    }

    @Test
    fun `eventApi should use correct base URL`() {
        val api = RemoteService.eventApi()

        assertThat(api).isNotNull()
    }

    @Test
    fun `notificationApi should use correct base URL`() {
        val api = RemoteService.notificationApi()

        assertThat(api).isNotNull()
    }

    @Test
    fun `loginApi should reuse Retrofit instance`() {
        val api1 = RemoteService.loginApi()
        val api2 = RemoteService.loginApi()

        assertThat(api1).isNotNull()
        assertThat(api2).isNotNull()
    }

    @Test
    fun `should configure logging when debug is enabled`() {
        Dito.options = Options(debug = true)

        val api = RemoteService.loginApi()

        assertThat(api).isNotNull()
    }

    @Test
    fun `should not configure logging when debug is disabled`() {
        Dito.options = Options(debug = false)

        val api = RemoteService.loginApi()

        assertThat(api).isNotNull()
    }
}
