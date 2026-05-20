import Foundation

public struct DitoNotificationReceived: Sendable {

  var reference: String = ""
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

  init(with userInfo: [AnyHashable: Any]) {
    self.notification = Self.stringValue(userInfo, keys: "notification")
    self.deeplink = Self.stringValue(userInfo, keys: "link")
    self.reference = Self.stringValue(userInfo, keys: "reference")
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
