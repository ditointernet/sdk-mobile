package br.com.dito.ditosdk.notification

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * O dump `DITO_PUSH_PAYLOAD` existe para depurar entrega e clique, e o logcat não é
 * lido só por quem programa: ele entra em bug report e em captura de suporte. Nem
 * identidade nem credencial podem sair em claro dali.
 */
class DitoNotificationHandlerPayloadLogTest {

    @Test
    fun `redige a identidade do utilizador`() {
        val rendered = DitoNotificationHandler.redactPayload(
            mapOf(
                "notification" to "01KYW2YGTQF4MHPTXW5M0WRJG0",
                "user_id" to "1ecd17c6b3587e8c9a4e5b77d0d89674e67b2e4a",
                "identifier" to "1ecd17c6b3587e8c9a4e5b77d0d89674e67b2e4a",
                "token" to "fcm-token-real",
            ),
        )

        assertFalse("user_id em claro", rendered.contains("1ecd17c6b3587e8c9a4e5b77d0d89674e67b2e4a"))
        assertFalse("token em claro", rendered.contains("fcm-token-real"))
        assertTrue(rendered.contains("user_id=<redacted>"))
        assertTrue(rendered.contains("identifier=<redacted>"))
        assertTrue("o que não é segredo continua legível", rendered.contains("notification=01KYW2YGTQF4MHPTXW5M0WRJG0"))
    }

    /**
     * O channel-sender põe a chave da plataforma **dentro do payload**: numa campanha
     * real de produção o data map chegou com `api_key` ao lado de `notification_name`
     * e da lista de acções.
     */
    @Test
    fun `redige a credencial da plataforma`() {
        val rendered = DitoNotificationHandler.redactPayload(
            mapOf(
                "notification_name" to "Campanha de teste Rich Push",
                "api_key" to "chave-de-plataforma-real",
                "api_secret" to "secret-real",
                "signature" to "sha1-real",
            ),
        )

        assertFalse("api_key em claro", rendered.contains("chave-de-plataforma-real"))
        assertFalse("api_secret em claro", rendered.contains("secret-real"))
        assertFalse("signature em claro", rendered.contains("sha1-real"))
        assertTrue(rendered.contains("api_key=<redacted>"))
        assertTrue(rendered.contains("notification_name=Campanha de teste Rich Push"))
    }

    /**
     * "Esta chave chegou vazia" é o sinal que se vai ler quando algo não chega — foi
     * assim que a perda de eventos por `reference` ausente apareceu. Redigir o vazio
     * apagaria justamente a evidência.
     */
    @Test
    fun `mantem visivel o campo que chegou vazio`() {
        val rendered = DitoNotificationHandler.redactPayload(
            mapOf("reference" to "", "user_id" to "  ", "notification" to "nid"),
        )

        assertEquals("reference=&user_id=  &notification=nid", rendered)
    }

    @Test
    fun `escapa quebra de linha para o dump continuar em uma linha`() {
        val rendered = DitoNotificationHandler.redactPayload(mapOf("message" to "linha1\nlinha2"))

        assertEquals("message=linha1\\nlinha2", rendered)
        assertFalse(rendered.contains("\n"))
    }
}
