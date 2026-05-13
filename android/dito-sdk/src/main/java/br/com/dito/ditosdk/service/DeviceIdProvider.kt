package br.com.dito.ditosdk.service

import android.content.Context
import android.provider.Settings

internal object DeviceIdProvider {
    fun get(context: Context): String =
        Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID) ?: ""
}
