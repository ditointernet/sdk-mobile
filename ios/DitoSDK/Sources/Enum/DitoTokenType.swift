//
//  DitoTokenType.swift
//  DitoSDK
//
//  Created by Rodrigo Damacena Gamarra Maciel on 27/01/21.
//

import Foundation

/// Token type for push notifications
/// - Note: This enum is deprecated. DitoSDK now only supports Firebase Cloud Messaging (FCM) tokens.
///         The `apple` case is no longer supported as DitoSDK handles only FCM tokens directly.
@available(*, deprecated, message: "DitoSDK now only supports Firebase Cloud Messaging tokens. Use registerDevice(token:) without specifying tokenType.")
public enum DitoTokenType: String {
    /// Firebase Cloud Messaging token (default and only supported type)
    case firebase
    /// Apple Push Notification Service token (deprecated, no longer supported)
    @available(*, deprecated, message: "APNS tokens are not supported. Use Firebase Cloud Messaging tokens only.")
    case apple
}
