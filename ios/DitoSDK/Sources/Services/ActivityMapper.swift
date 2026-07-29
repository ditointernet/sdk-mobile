import Foundation
import SwiftProtobuf
import UIKit

struct ActivityMapper {
    private let deviceOsVersion: String
    private let deviceModel: String

    init() {
        deviceOsVersion = UIDevice.current.systemVersion
        deviceModel = UIDevice.current.model
    }

    func mapFromDitoUser(userData: DitoUser?, userId: String) -> Mobileingest_V1_Activity {
        var identify = Mobileingest_V1_IdentifyActivity()
        identify.name = userData?.name ?? ""
        identify.email = userData?.email ?? ""
        identify.birthday = userData?.birthday ?? ""
        identify.gender = userData?.gender ?? ""
        if let location = userData?.location, !location.isEmpty {
            var address = Mobileingest_V1_Address()
            address.street = location
            identify.address = address
        }
        if let dataJson = userData?.data {
            identify.customData = customDataFromJson(dataJson)
        }
        var activity = Mobileingest_V1_Activity()
        activity.id = UUID().uuidString
        activity.type = .activityIdentify
        activity.identify = identify
        activity.timestamp = nowTimestamp()
        return activity
    }

    func mapFromDitoEvent(_ event: DitoEvent) -> Mobileingest_V1_Activity {
        var track = Mobileingest_V1_Activity.TrackActivity()
        track.event = event.action ?? ""
        if let revenue = event.revenue {
            track.revenue = Float(revenue)
        }
        if let dataJson = event.data {
            track.data = customDataFromJson(dataJson)
        }
        var activity = Mobileingest_V1_Activity()
        activity.id = UUID().uuidString
        activity.type = .activityTrack
        activity.track = track
        activity.timestamp = nowTimestamp()
        return activity
    }

    func mapFromEventRequest(_ req: DitoEventRequest) -> Mobileingest_V1_Activity {
        mapFromDitoEvent(req.event)
    }

    func mapFromTokenRequest(_ req: DitoTokenRequest, isRegister: Bool) -> Mobileingest_V1_Activity {
        var activity = Mobileingest_V1_Activity()
        activity.id = UUID().uuidString
        activity.type = .activityRegister
        activity.timestamp = nowTimestamp()
        if isRegister {
            var register = Mobileingest_V1_Activity.TokenRegisterActivity()
            register.token = req.token
            register.provider = .providerFcm
            activity.tokenRegister = register
        } else {
            var unregister = Mobileingest_V1_Activity.TokenUnregisterActivity()
            unregister.token = req.token
            unregister.provider = .providerFcm
            activity.tokenUnregister = unregister
        }
        return activity
    }

    func mapFromNotificationOpen(_ req: DitoNotificationOpenRequest) -> Mobileingest_V1_Activity {
        buildPushClickActivity(
            notificationId: req.data.notification,
            identifier: req.data.identifier,
            data: req.data.clickCustomData
        )
    }

    func mapNotificationClick(
        notificationId: String,
        identifier: String,
        data: [String: String] = [:]
    ) -> Mobileingest_V1_Activity {
        buildPushClickActivity(notificationId: notificationId, identifier: identifier, data: data)
    }

    /// Builds the `click-notification` activity.
    ///
    /// Per D-03 an action-button tap is *not* a new event: it reuses this same
    /// activity with `action_id` / `action_label` merged into `data`, so no
    /// `sdk-service` change is required.
    private func buildPushClickActivity(
        notificationId: String,
        identifier: String,
        data: [String: String] = [:]
    ) -> Mobileingest_V1_Activity {
        var notifInfo = Mobileingest_V1_NotificationInfo()
        notifInfo.notificationID = notificationId
        notifInfo.identifier = identifier
        var click = Mobileingest_V1_Activity.TrackPushClickActivity()
        click.notification = notifInfo
        click.data = customDataFromStrings(data)
        var activity = Mobileingest_V1_Activity()
        activity.id = UUID().uuidString
        activity.type = .activityTrack
        activity.trackPushClick = click
        activity.timestamp = nowTimestamp()
        return activity
    }

    private func customDataFromStrings(_ values: [String: String]) -> [String: Mobileingest_V1_CustomData] {
        var result: [String: Mobileingest_V1_CustomData] = [:]
        for (key, value) in values {
            var cdValue = Mobileingest_V1_CustomDataValue()
            cdValue.stringValue = value
            var cd = Mobileingest_V1_CustomData()
            cd.single = cdValue
            result[key] = cd
        }
        return result
    }

    func buildRequest(userId: String, activities: [Mobileingest_V1_Activity]) -> Mobileingest_V1_Request {
        var request = Mobileingest_V1_Request()
        request.activities = activities
        request.userID = userId
        request.device = buildDeviceInfo()
        request.sdk = buildSDKInfo()
        request.app = buildAppInfo()
        return request
    }

    private func buildDeviceInfo() -> Mobileingest_V1_DeviceInfo {
        var info = Mobileingest_V1_DeviceInfo()
        info.os = .ios
        info.deviceID = DeviceIdProvider.get()
        info.osVersion = deviceOsVersion
        info.deviceModel = deviceModel
        return info
    }

    private func buildSDKInfo() -> Mobileingest_V1_SDKInfo {
        var sdk = Mobileingest_V1_SDKInfo()
        sdk.version = Bundle(for: Dito.self).infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        sdk.lang = "swift"
        return sdk
    }

    private func buildAppInfo() -> Mobileingest_V1_AppInfo {
        var app = Mobileingest_V1_AppInfo()
        app.id = Dito.bundleId
        app.version = Bundle(for: Dito.self).infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        app.platform = "iOS"
        return app
    }

    private func nowTimestamp() -> Google_Protobuf_Timestamp {
        let now = Date()
        return Google_Protobuf_Timestamp(date: now)
    }

    private func customDataFromJson(_ json: String) -> [String: Mobileingest_V1_CustomData] {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            DitoLogger.warning("⚠️ [ActivityMapper] Falha ao parsear customData JSON: \(json.prefix(100))")
            return [:]
        }
        var result: [String: Mobileingest_V1_CustomData] = [:]
        for (key, value) in dict {
            var cdValue = Mobileingest_V1_CustomDataValue()
            if value is NSNull {
                cdValue.nullValue = Mobileingest_V1_CustomDataNullValue()
            } else if CFGetTypeID(value as AnyObject) == CFBooleanGetTypeID(), let boolVal = value as? Bool {
                cdValue.boolValue = boolVal
            } else if let num = value as? Double {
                cdValue.numberValue = num
            } else if let str = value as? String {
                cdValue.stringValue = str
            } else {
                DitoLogger.warning("⚠️ [ActivityMapper] Tipo não suportado para chave '\(key)': \(type(of: value))")
                continue
            }
            var cd = Mobileingest_V1_CustomData()
            cd.single = cdValue
            result[key] = cd
        }
        return result
    }
}
