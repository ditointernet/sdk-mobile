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

/** Lê o formato de [formatToISO]; `null` se não for válido. */
internal fun parseISO(value: String): Date? =
    try {
        SimpleDateFormat(ISO_PATTERN, Locale.US).apply { isLenient = false }.parse(value)
    } catch (_: ParseException) {
        null
    }

private const val ISO_PATTERN = "yyyy-MM-dd'T'HH:mm:ssZ"
