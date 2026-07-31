package br.com.dito.ditosdk.notification

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Botão de ação de uma notificação rica.
 *
 * O backend já resolve o [link] para o sistema operacional do device, portanto cada botão carrega
 * exatamente um destino.
 *
 * @param id Identificador do botão (`^[a-z0-9_]{1,32}$`), único dentro do push
 * @param label Texto exibido no botão (até 25 caracteres)
 * @param link URL ou deeplink aberto ao tocar no botão
 */
data class DitoNotificationAction(
    val id: String,
    val label: String,
    val link: String,
)

/**
 * Faz o parsing defensivo dos campos ricos (`actions` e `custom_data`) que chegam no data map do FCM
 * como strings JSON. Payload inválido nunca derruba a notificação: o campo é simplesmente ignorado.
 */
internal object DitoRichPushParser {

    private const val TAG = "DitoRichPushParser"

    /** O contrato garante no máximo 2 botões; o excedente é descartado. */
    const val MAX_ACTIONS = 2

    fun parseActions(json: String?): List<DitoNotificationAction> {
        if (json.isNullOrBlank()) return emptyList()
        return try {
            val array = JSONArray(json)
            val actions = LinkedHashMap<String, DitoNotificationAction>()
            for (index in 0 until array.length()) {
                if (actions.size >= MAX_ACTIONS) {
                    Log.w(TAG, "More than $MAX_ACTIONS actions received; extra actions ignored")
                    break
                }
                val item = array.optJSONObject(index) ?: continue
                val id = item.optString("id").trim()
                val label = item.optString("label").trim()
                if (id.isEmpty() || label.isEmpty()) continue
                if (actions.containsKey(id)) continue
                actions[id] = DitoNotificationAction(
                    id = id,
                    label = label,
                    link = item.optString("link").trim(),
                )
            }
            actions.values.toList()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse notification actions: ${e.message}")
            emptyList()
        }
    }

    fun parseCustomData(json: String?): Map<String, String> {
        if (json.isNullOrBlank()) return emptyMap()
        return try {
            val obj = JSONObject(json)
            val data = LinkedHashMap<String, String>()
            obj.keys().forEach { key ->
                if (key.isBlank() || obj.isNull(key)) return@forEach
                data[key] = obj.optString(key)
            }
            data
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse notification custom data: ${e.message}")
            emptyMap()
        }
    }
}
