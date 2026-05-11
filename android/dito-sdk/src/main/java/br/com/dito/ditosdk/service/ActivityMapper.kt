package br.com.dito.ditosdk.service

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import br.com.dito.ditosdk.BuildConfig
import br.com.dito.ditosdk.CustomData
import br.com.dito.ditosdk.Event
import br.com.dito.ditosdk.Identify
import br.com.dito.ditosdk.IdentifyOff
import com.google.gson.Gson
import com.google.protobuf.Timestamp
import java.util.UUID
import mobileingest.v1.Api

internal class ActivityMapper(private val context: Context) {

    private val gson = Gson()

    fun fromIdentifyOff(off: IdentifyOff): Identify {
        val identify = Identify(off.id)
        identify.name = off.name
        identify.email = off.email
        identify.gender = off.gender
        identify.birthday = off.birthday
        identify.location = off.location
        identify.data = customDataFromJson(off.customDataJson)
        return identify
    }

    fun eventFromOffline(action: String, revenue: Float?, dataJson: String?, timestamp: String): Event {
        val e = Event(action, revenue?.toDouble())
        e.createdAt = timestamp
        e.data = customDataFromJson(dataJson)
        return e
    }

    fun mapIdentify(identify: Identify, activityId: String = UUID.randomUUID().toString()): Api.Activity {
        val iaBuilder = Api.IdentifyActivity.newBuilder()
            .setName(identify.name ?: "")
            .setEmail(identify.email ?: "")
            .setBirthday(identify.birthday ?: "")
            .setGender(identify.gender ?: "")
            .setPhone("")
            .putAllCustomData(customDataToProto(identify.data))
        if (!identify.location.isNullOrBlank()) {
            iaBuilder.setAddress(
                Api.Address.newBuilder().setStreet(identify.location).build(),
            )
        }
        val ia = iaBuilder.build()
        return Api.Activity.newBuilder()
            .setId(activityId)
            .setType(Api.ActivityType.ACTIVITY_IDENTIFY)
            .setIdentify(ia)
            .setTimestamp(nowTimestamp())
            .build()
    }

    fun mapTrack(event: Event, activityId: String = UUID.randomUUID().toString()): Api.Activity {
        val track = Api.Activity.TrackActivity.newBuilder()
            .setEvent(event.action)
            .setRevenue(event.revenue?.toFloat() ?: 0f)
            .putAllData(customDataToProto(event.data))
            .build()
        return Api.Activity.newBuilder()
            .setId(activityId)
            .setType(Api.ActivityType.ACTIVITY_TRACK)
            .setTrack(track)
            .setTimestamp(nowTimestamp())
            .build()
    }

    fun mapTokenRegister(token: String, activityId: String = UUID.randomUUID().toString()): Api.Activity {
        val tr = Api.Activity.TokenRegisterActivity.newBuilder()
            .setToken(token)
            .setProvider(Api.PushProvider.PROVIDER_FCM)
            .build()
        return Api.Activity.newBuilder()
            .setId(activityId)
            .setType(Api.ActivityType.ACTIVITY_REGISTER)
            .setTokenRegister(tr)
            .setTimestamp(nowTimestamp())
            .build()
    }

    fun mapTokenUnregister(token: String, activityId: String = UUID.randomUUID().toString()): Api.Activity {
        val tu = Api.Activity.TokenUnregisterActivity.newBuilder()
            .setToken(token)
            .setProvider(Api.PushProvider.PROVIDER_FCM)
            .build()
        // ActivityType enum has no ACTIVITY_UNREGISTER variant; the backend differentiates
        // register from unregister via the activity oneof field (token_unregister vs token_register).
        return Api.Activity.newBuilder()
            .setId(activityId)
            .setType(Api.ActivityType.ACTIVITY_REGISTER)
            .setTokenUnregister(tu)
            .setTimestamp(nowTimestamp())
            .build()
    }

    fun mapNotificationClick(
        notificationId: String,
        identifier: String,
        activityId: String = UUID.randomUUID().toString(),
    ): Api.Activity {
        val ni = Api.NotificationInfo.newBuilder()
            .setNotificationId(notificationId)
            .setIdentifier(identifier)
            .build()
        val click = Api.Activity.TrackPushClickActivity.newBuilder()
            .setNotification(ni)
            .build()
        return Api.Activity.newBuilder()
            .setId(activityId)
            .setType(Api.ActivityType.ACTIVITY_TRACK)
            .setTrackPushClick(click)
            .setTimestamp(nowTimestamp())
            .build()
    }

    fun buildRequest(userId: String, activities: List<Api.Activity>, token: String?): Api.Request {
        val device = buildDeviceInfo(token)
        val sdk = Api.SDKInfo.newBuilder()
            .setVersion(BuildConfig.DITO_SDK_VERSION)
            .setLang("kotlin")
            .build()
        val app = buildAppInfo()
        return Api.Request.newBuilder()
            .addAllActivities(activities)
            .setUserId(userId)
            .setDevice(device)
            .setSdk(sdk)
            .setApp(app)
            .build()
    }

    fun buildDeviceInfo(token: String?): Api.DeviceInfo =
        Api.DeviceInfo.newBuilder()
            .setOs(Api.DeviceOs.DEVICE_OS_ANDROID)
            .setDeviceId(DeviceIdProvider.get(context))
            .setToken(token ?: "")
            .setOsVersion(Build.VERSION.RELEASE ?: "")
            .setDeviceModel(Build.MODEL ?: "")
            .build()

    private fun buildAppInfo(): Api.AppInfo {
        val p = context.packageName
        val ver = try {
            val pi = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getPackageInfo(p, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(p, 0)
            }
            pi.versionName ?: ""
        } catch (_: Exception) {
            ""
        }
        return Api.AppInfo.newBuilder()
            .setId(p)
            .setVersion(ver)
            .setPlatform("Android")
            .build()
    }

    internal fun customDataToProto(custom: CustomData?): Map<String, Api.CustomData> {
        custom ?: return emptyMap()
        return custom.params.mapNotNull { (k, v) ->
            val cdValue = Api.CustomDataValue.newBuilder()
            when (v) {
                is String -> cdValue.setStringValue(v)
                is Double -> cdValue.setNumberValue(v)
                is Float -> cdValue.setNumberValue(v.toDouble())
                is Int -> cdValue.setNumberValue(v.toDouble())
                is Long -> cdValue.setNumberValue(v.toDouble())
                is Boolean -> cdValue.setBoolValue(v)
                else -> {
                    Log.w("ActivityMapper", "customDataToProto: tipo não suportado para chave '$k': ${v::class.java.simpleName}")
                    return@mapNotNull null
                }
            }
            val cd = Api.CustomData.newBuilder().setSingle(cdValue.build()).build()
            k to cd
        }.toMap()
    }

    fun customDataFromJson(json: String?): CustomData? {
        if (json.isNullOrBlank()) return null
        return try {
            val map = gson.fromJson(json, Map::class.java) as? Map<*, *> ?: return null
            CustomData().apply {
                map.forEach { (k, v) ->
                    if (k != null && v != null) {
                        when (v) {
                            is String -> add(k.toString(), v)
                            is Double -> add(k.toString(), v)
                            is Int -> add(k.toString(), v)
                            is Boolean -> add(k.toString(), v)
                            else -> params[k.toString()] = v
                        }
                    }
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    fun customDataToJson(custom: CustomData?): String? {
        if (custom == null || custom.params.isEmpty()) return null
        return gson.toJson(custom.params)
    }

    private fun nowTimestamp(): Timestamp {
        val now = java.time.Instant.now()
        return Timestamp.newBuilder()
            .setSeconds(now.epochSecond)
            .setNanos(now.nano)
            .build()
    }
}
