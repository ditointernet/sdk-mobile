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
import br.com.dito.ditosdk.utils.parseISO
import com.google.gson.Gson
import com.google.protobuf.Timestamp
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import mobileingest.v1.Api

private const val PUSH_CHANNEL = "mobile"

internal class DeviceIdUnavailableException :
    IllegalStateException("device_id indisponível: nenhum request sai para o mobile-ingest sem ele.")

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

    fun mapAnonymousIdentify(): Api.Activity {
        val identify = Identify("").apply {
            data = CustomData().apply {
                add("device_model", Build.MODEL ?: "")
                add("sdk_version", BuildConfig.DITO_SDK_VERSION)
            }
        }
        return mapIdentify(identify)
    }

    /** @param queuedAt hora gravada na fila (reenvio); sem ela, a hora atual. */
    fun mapTrack(
        event: Event,
        activityId: String = UUID.randomUUID().toString(),
        queuedAt: String? = null,
    ): Api.Activity {
        val track = Api.Activity.TrackActivity.newBuilder()
            .setEvent(event.action)
            .setRevenue(event.revenue?.toFloat() ?: 0f)
            .putAllData(customDataToProto(event.data))
            .build()
        return Api.Activity.newBuilder()
            .setId(activityId)
            .setType(Api.ActivityType.ACTIVITY_TRACK)
            .setTrack(track)
            .setTimestamp(timestampOf(queuedAt))
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

    /**
     * @param data Custom data extra do clique (ex.: `action_id`/`action_label` de um botão).
     *   O backend mescla esse mapa no custom data do evento `click-notification` sem whitelist.
     */
    fun mapNotificationClick(
        notificationId: String,
        identifier: String,
        activityId: String = UUID.randomUUID().toString(),
        data: Map<String, String> = emptyMap(),
        logId: String = "",
        notificationName: String = "",
    ): Api.Activity {
        val clickBuilder = Api.Activity.TrackPushClickActivity.newBuilder()
            .setNotification(notificationInfo(notificationId, logId, notificationName, identifier))
        if (data.isNotEmpty()) {
            val customData = CustomData().apply { data.forEach { (key, value) -> add(key, value) } }
            clickBuilder.putAllData(customDataToProto(customData))
        }
        val click = clickBuilder.build()
        return Api.Activity.newBuilder()
            .setId(activityId)
            .setType(Api.ActivityType.ACTIVITY_TRACK)
            .setTrackPushClick(click)
            .setTimestamp(nowTimestamp())
            .build()
    }

    fun mapPushReceipt(
        notificationId: String,
        logId: String,
        notificationName: String,
        identifier: String,
        activityId: String = UUID.randomUUID().toString(),
        queuedAt: String? = null,
    ): Api.Activity {
        val receipt = Api.Activity.TrackPushReceiptActivity.newBuilder()
            .setNotification(notificationInfo(notificationId, logId, notificationName, identifier))
            .build()
        return Api.Activity.newBuilder()
            .setId(activityId)
            .setType(Api.ActivityType.ACTIVITY_TRACK)
            .setTrackPushReceipt(receipt)
            .setTimestamp(timestampOf(queuedAt))
            .build()
    }

    private fun notificationInfo(
        notificationId: String,
        logId: String,
        notificationName: String,
        identifier: String,
    ): Api.NotificationInfo = Api.NotificationInfo.newBuilder()
        .setNotificationId(notificationId)
        .setDispatchId(logId)
        .setName(notificationName)
        .setIdentifier(identifier)
        .setChannel(PUSH_CHANNEL)
        .build()

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

    fun buildDeviceInfo(token: String?): Api.DeviceInfo {
        val id = requireDeviceId()
        return Api.DeviceInfo.newBuilder()
            .setOs(Api.DeviceOs.DEVICE_OS_ANDROID)
            .setDeviceId(id)
            .setToken(token ?: "")
            .setOsVersion(Build.VERSION.RELEASE ?: "")
            .setDeviceModel(Build.MODEL ?: "")
            .build()
    }

    fun requireDeviceId(): String {
        val id = deviceId
        if (id.isEmpty()) {
            throw DeviceIdUnavailableException().also { Log.e("ActivityMapper", it.message, it) }
        }
        return id
    }

    @Volatile
    private var cachedDeviceId: String? = null

    private val deviceIdMissing = AtomicBoolean(false)

    /** Chamado uma vez quando uma leitura acha o device_id depois de uma leitura vazia. */
    @Volatile
    var onDeviceIdAvailable: (() -> Unit)? = null

    // Vazio não fica em cache: o ANDROID_ID pode aparecer numa leitura seguinte.
    val deviceId: String
        get() = resolveDeviceId().also { (_, arrived) -> if (arrived) onDeviceIdAvailable?.invoke() }.first

    /** Igual a [deviceId], sem avisar [onDeviceIdAvailable]: para quem já vai drenar a fila. */
    fun deviceIdForFlush(): String = resolveDeviceId().first

    /** Lê sem avisar [onDeviceIdAvailable]; true se foi esta leitura que achou o id depois de uma vazia. */
    fun claimDeviceIdArrival(): Boolean = resolveDeviceId().second

    private fun resolveDeviceId(): Pair<String, Boolean> {
        cachedDeviceId?.let { return it to false }
        val id = DeviceIdProvider.get(context)
        if (id.isEmpty()) {
            deviceIdMissing.set(true)
            return id to false
        }
        cachedDeviceId = id
        return id to deviceIdMissing.getAndSet(false)
    }

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

    private fun nowTimestamp(): Timestamp = toTimestamp(java.time.Instant.now())

    // Hora gravada na fila (reenvio); sem ela ou inválida, a hora atual.
    private fun timestampOf(queuedAt: String?): Timestamp =
        queuedAt?.let(::parseISO)?.let { toTimestamp(it.toInstant()) } ?: nowTimestamp()

    private fun toTimestamp(instant: java.time.Instant): Timestamp =
        Timestamp.newBuilder()
            .setSeconds(instant.epochSecond)
            .setNanos(instant.nano)
            .build()
}
