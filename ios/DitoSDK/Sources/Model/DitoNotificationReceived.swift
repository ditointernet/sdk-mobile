import DitoSDKNotificationService
import Foundation

public struct DitoNotificationReceived: Sendable {

  var identifier: String = ""
  var notification: String = ""
  var notificationLogId: String = ""
  var userId: String = ""
  var deviceType: String = ""
  var channel: String = ""
  var notificationName: String = ""
  var title: String = ""
  var message: String = ""
  public var deeplink: String = ""
  var logId: String = ""

  // MARK: Rich push

  /// `data.image`, empty when the campaign has no image.
  public var image: String = ""
  /// Action buttons declared by `data.actions`, at most two, already validated.
  public var actions: [DitoPushAction] = []
  /// `data.custom_data`, already variable-substituted by the backend.
  public var customData: [String: String] = [:]
  /// Identifier of the tapped action button, empty for a tap on the body.
  public var actionId: String = ""
  /// Label of the tapped action button, empty for a tap on the body.
  public var actionLabel: String = ""

  /// Deeplink to follow for this interaction.
  ///
  /// A button carries its own already-iOS-resolved link; falls back to the
  /// notification's own deeplink when the body was tapped or the button has none.
  public var resolvedLink: String {
    if !actionId.isEmpty, let action = actions.first(where: { $0.id == actionId }), !action.link.isEmpty {
      return action.link
    }
    return deeplink
  }

  /// Custom data map carried by the `click-notification` event.
  ///
  /// Per D-03 a button tap reuses the existing click event and merely adds
  /// `action_id` / `action_label`, so `sdk-service` needs no change. Those two
  /// keys cannot collide with campaign data: `DitoRichPushPayload` strips them
  /// while parsing `custom_data`.
  public var clickCustomData: [String: String] {
    var result = customData
    if !actionId.isEmpty { result[DitoRichPushKeys.actionId] = actionId }
    if !actionLabel.isEmpty { result[DitoRichPushKeys.actionLabel] = actionLabel }
    return result
  }

  /// Builds the model from a push payload.
  ///
  /// `reference` is deliberately not read. The field is being retired from Dito
  /// payloads and attribution anchors on `user_id`, so nothing downstream may
  /// depend on it — a payload that still carries the key is simply ignored.
  init(with userInfo: [AnyHashable: Any]) {
    self.notification = Self.stringValue(userInfo, keys: "notification")
    self.deeplink = Self.stringValue(userInfo, keys: "link")
    let userIdValue = Self.stringValue(userInfo, keys: "user_id", "userId")
    self.identifier = userIdValue
    self.userId = userIdValue
    self.notificationLogId = Self.stringValue(userInfo, keys: "log_id")
    self.deviceType = Self.stringValue(userInfo, keys: "device_type")
    self.channel = Self.stringValue(userInfo, keys: "channel")
    self.notificationName = Self.stringValue(userInfo, keys: "notification_name")
    self.title = Self.stringValue(userInfo, keys: "title")
    self.message = Self.stringValue(userInfo, keys: "message")
    self.logId = Self.stringValue(userInfo, keys: "log_id")

    let payload = DitoRichPushPayload(userInfo: userInfo)
    self.image = payload.imageURL?.absoluteString ?? ""
    self.actions = payload.actions
    self.customData = payload.customData
  }

  static func stringValue(_ userInfo: [AnyHashable: Any], keys: String...) -> String {
    for key in keys {
      if let value = stringFromDictionary(userInfo, key: key) {
        return value
      }
      if let data = userInfo["data"] as? [String: Any],
         let value = stringFromDictionary(data, key: key) {
        return value
      }
      if let gcm = userInfo["gcm"] as? [String: Any],
         let value = stringFromDictionary(gcm, key: key) {
        return value
      }
    }
    return ""
  }

  private static func stringFromDictionary(_ dictionary: [AnyHashable: Any], key: String) -> String? {
    guard let raw = dictionary[key] else {
      return nil
    }
    if let string = raw as? String {
      let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }
    if let number = raw as? NSNumber {
      let trimmed = number.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }
    return nil
  }
}
