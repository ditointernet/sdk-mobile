//
//  DitoDataNotification.swift
//  DitoSDK
//
//  Created by Rodrigo Damacena Gamarra Maciel on 27/01/21.
//

import DitoSDKNotificationService
import Foundation

struct DitoDataNotification: Codable {

    let identifier: String
    let reference: String
    let notification: String
    let notificationLogId: String
    let userId: String
    let deviceType: String
    let channel: String
    let notificationName: String
    let title: String
    let message: String
    let link: String
    let logId: String

    // MARK: Rich push

    /// `data.image`, empty when the campaign has no image.
    let image: String
    /// `data.custom_data`, already variable-substituted by the backend.
    let customData: [String: String]
    /// Identifier of the tapped action button, empty for a tap on the body.
    let actionId: String
    /// Label of the tapped action button, empty for a tap on the body.
    let actionLabel: String

    /// Custom data map carried by the `click-notification` event.
    ///
    /// Per D-03 a button tap reuses the existing click event and merely adds
    /// `action_id` / `action_label`, so `sdk-service` needs no change.
    var clickCustomData: [String: String] {
        var result = customData
        if !actionId.isEmpty { result["action_id"] = actionId }
        if !actionLabel.isEmpty { result["action_label"] = actionLabel }
        return result
    }

    init(from userInfo: [AnyHashable: Any], actionId: String = "", actionLabel: String = "") {
        self.identifier = (userInfo["user_id"] as? String) ?? ""
        self.reference = (userInfo["reference"] as? String) ?? ""
        self.notification = (userInfo["notification"] as? String) ?? ""
        self.notificationLogId = (userInfo["log_id"] as? String) ?? ""
        self.userId = (userInfo["user_id"] as? String) ?? ""
        self.deviceType = (userInfo["device_type"] as? String) ?? ""
        self.channel = (userInfo["channel"] as? String) ?? ""
        self.notificationName = (userInfo["notification_name"] as? String) ?? ""
        self.title = (userInfo["title"] as? String) ?? ""
        self.message = (userInfo["message"] as? String) ?? ""
        self.link = (userInfo["link"] as? String) ?? ""
        self.logId = (userInfo["log_id"] as? String) ?? ""

        let payload = DitoRichPushPayload(userInfo: userInfo)
        self.image = payload.imageURL?.absoluteString ?? ""
        self.customData = payload.customData
        self.actionId = actionId
        self.actionLabel = actionLabel
    }

    // Legacy initializer for backward compatibility
    init(identifier: String, reference: String) {
        self.identifier = identifier
        self.reference = reference
        self.notification = ""
        self.notificationLogId = ""
        self.userId = identifier
        self.deviceType = ""
        self.channel = ""
        self.notificationName = ""
        self.title = ""
        self.message = ""
        self.link = ""
        self.logId = ""
        self.image = ""
        self.customData = [:]
        self.actionId = ""
        self.actionLabel = ""
    }

    init(
        identifier: String,
        reference: String,
        notification: String,
        notificationLogId: String,
        userId: String,
        deviceType: String,
        channel: String,
        notificationName: String,
        title: String,
        message: String,
        link: String,
        logId: String,
        image: String = "",
        customData: [String: String] = [:],
        actionId: String = "",
        actionLabel: String = ""
    ) {
        self.identifier = identifier
        self.reference = reference
        self.notification = notification
        self.notificationLogId = notificationLogId
        self.userId = userId
        self.deviceType = deviceType
        self.channel = channel
        self.notificationName = notificationName
        self.title = title
        self.message = message
        self.link = link
        self.logId = logId
        self.image = image
        self.customData = customData
        self.actionId = actionId
        self.actionLabel = actionLabel
    }

    enum CodingKeys: String, CodingKey {
        case identifier
        case reference
        case notification
        case notificationLogId = "notification_log_id"
        case userId = "user_id"
        case deviceType = "device_type"
        case channel
        case notificationName = "notification_name"
        case title
        case message
        case link
        case logId = "log_id"
        case image
        case customData = "custom_data"
        case actionId = "action_id"
        case actionLabel = "action_label"
    }

    /// Lenient decoder.
    ///
    /// Rows persisted by an older SDK predate the rich-push keys, so every field
    /// is optional on read. Without this, upgrading would make queued
    /// notification-open retries fail to decode and be dropped silently.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func string(_ key: CodingKeys) -> String {
            ((try? container.decodeIfPresent(String.self, forKey: key)) ?? nil) ?? ""
        }
        self.identifier = string(.identifier)
        self.reference = string(.reference)
        self.notification = string(.notification)
        self.notificationLogId = string(.notificationLogId)
        self.userId = string(.userId)
        self.deviceType = string(.deviceType)
        self.channel = string(.channel)
        self.notificationName = string(.notificationName)
        self.title = string(.title)
        self.message = string(.message)
        self.link = string(.link)
        self.logId = string(.logId)
        self.image = string(.image)
        self.customData =
            ((try? container.decodeIfPresent([String: String].self, forKey: .customData)) ?? nil) ?? [:]
        self.actionId = string(.actionId)
        self.actionLabel = string(.actionLabel)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(reference, forKey: .reference)
        try container.encode(notification, forKey: .notification)
        try container.encode(notificationLogId, forKey: .notificationLogId)
        try container.encode(userId, forKey: .userId)
        try container.encode(deviceType, forKey: .deviceType)
        try container.encode(channel, forKey: .channel)
        try container.encode(notificationName, forKey: .notificationName)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encode(link, forKey: .link)
        try container.encode(logId, forKey: .logId)
        // Rich-push keys are written only when present, keeping the payload
        // byte-identical to the previous format for non-rich campaigns.
        if !image.isEmpty { try container.encode(image, forKey: .image) }
        if !customData.isEmpty { try container.encode(customData, forKey: .customData) }
        if !actionId.isEmpty { try container.encode(actionId, forKey: .actionId) }
        if !actionLabel.isEmpty { try container.encode(actionLabel, forKey: .actionLabel) }
    }
}
