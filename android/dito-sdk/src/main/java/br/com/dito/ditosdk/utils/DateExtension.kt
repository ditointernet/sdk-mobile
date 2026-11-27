package br.com.dito.ditosdk.utils

import java.text.ParseException
import java.text.SimpleDateFormat
import java.util.*

/**
 * Pattern: yyyy-MM-dd'T'HH:mm:ssZ
 */
fun Date.formatToISO(): String {
    val sdf = SimpleDateFormat(ISO_PATTERN, Locale.US)
    return sdf.format(this)
}

/**
 * Como [formatToISO], com milissegundos (yyyy-MM-dd'T'HH:mm:ss.SSSZ): é a hora gravada na fila, e
 * eventos do mesmo segundo precisam manter a ordem no reenvio.
 */
internal fun Date.formatToISOMillis(): String = SimpleDateFormat(ISO_MILLIS_PATTERN, Locale.US).format(this)

/** Lê o formato de [formatToISOMillis] ou o de [formatToISO] (linhas antigas); `null` se nenhum. */
internal fun parseISO(value: String): Date? =
    parse(value, ISO_MILLIS_PATTERN) ?: parse(value, ISO_PATTERN)

private fun parse(value: String, pattern: String): Date? =
    try {
        SimpleDateFormat(pattern, Locale.US).apply { isLenient = false }.parse(value)
    } catch (_: ParseException) {
        null
    }

private const val ISO_PATTERN = "yyyy-MM-dd'T'HH:mm:ssZ"
private const val ISO_MILLIS_PATTERN = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
