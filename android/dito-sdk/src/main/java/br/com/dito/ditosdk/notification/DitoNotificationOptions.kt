package br.com.dito.ditosdk.notification

import androidx.annotation.ColorInt
import androidx.annotation.DrawableRes

data class DitoNotificationOptions(
    @DrawableRes val smallIconResId: Int? = null,
    @DrawableRes val largeIconResId: Int? = null,
    val soundResourceName: String? = null,
    @ColorInt val accentColor: Int? = null,
    val badgeEnabled: Boolean = true
)
