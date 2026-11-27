package br.com.dito.ditosdk.tracking

import android.content.Context

internal class AnonymousState(context: Context) {
    private val prefs = context.getSharedPreferences("dito-anonymous", Context.MODE_PRIVATE)

    var identifyMark: String?
        get() = prefs.getString(KEY_IDENTIFY_MARK, null)
        set(value) = prefs.edit().putString(KEY_IDENTIFY_MARK, value).apply()

    var lastToken: String?
        get() = prefs.getString(KEY_LAST_TOKEN, null)
        set(value) = prefs.edit().putString(KEY_LAST_TOKEN, value).apply()

    val confirmedUserId: String? get() = prefs.getString(KEY_CONFIRMED_USER_ID, null)

    val confirmedToken: String? get() = prefs.getString(KEY_CONFIRMED_TOKEN, null)

    fun setConfirmed(userId: String?, token: String?) {
        prefs.edit().putString(KEY_CONFIRMED_USER_ID, userId).putString(KEY_CONFIRMED_TOKEN, token).apply()
    }

    private companion object {
        const val KEY_IDENTIFY_MARK = "anonymous_identify_mark"
        const val KEY_LAST_TOKEN = "last_push_token"
        const val KEY_CONFIRMED_USER_ID = "confirmed_register_user_id"
        const val KEY_CONFIRMED_TOKEN = "confirmed_register_token"
    }
}
