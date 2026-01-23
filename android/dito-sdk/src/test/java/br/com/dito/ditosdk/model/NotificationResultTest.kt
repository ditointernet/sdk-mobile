package br.com.dito.ditosdk.model

import br.com.dito.ditosdk.NotificationResult
import com.google.common.truth.Truth.assertThat
import org.junit.Test

class NotificationResultTest {

    @Test
    fun `NotificationResult should store notificationId`() {
        val result = NotificationResult(
            notificationId = "notif123",
            reference = "ref123",
            deepLink = "https://example.com"
        )

        assertThat(result.notificationId).isEqualTo("notif123")
    }

    @Test
    fun `NotificationResult should store reference`() {
        val result = NotificationResult(
            notificationId = "notif123",
            reference = "ref123",
            deepLink = "https://example.com"
        )

        assertThat(result.reference).isEqualTo("ref123")
    }

    @Test
    fun `NotificationResult should store deepLink`() {
        val result = NotificationResult(
            notificationId = "notif123",
            reference = "ref123",
            deepLink = "https://example.com"
        )

        assertThat(result.deepLink).isEqualTo("https://example.com")
    }

    @Test
    fun `NotificationResult should allow empty strings`() {
        val result = NotificationResult(
            notificationId = "",
            reference = "",
            deepLink = ""
        )

        assertThat(result.notificationId).isEmpty()
        assertThat(result.reference).isEmpty()
        assertThat(result.deepLink).isEmpty()
    }
}
