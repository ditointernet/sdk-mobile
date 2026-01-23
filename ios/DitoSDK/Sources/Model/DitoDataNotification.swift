//
//  DitoDataNotification.swift
//  DitoSDK
//
//  Created by Rodrigo Damacena Gamarra Maciel on 27/01/21.
//

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

    init(from userInfo: [AnyHashable: Any]) {
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
    }
}
