import Foundation

public struct DitoNotificationReceived {

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
    self.notification = (userInfo["notification"] as? String) ?? ""
    self.deeplink = (userInfo["link"] as? String) ?? ""
    self.reference = (userInfo["reference"] as? String) ?? ""
    self.identifier = (userInfo["user_id"] as? String) ?? ""
    self.notificationLogId = (userInfo["log_id"] as? String) ?? ""
    self.userId = (userInfo["user_id"] as? String) ?? ""
    self.deviceType = (userInfo["device_type"] as? String) ?? ""
    self.channel = (userInfo["channel"] as? String) ?? ""
    self.notificationName = (userInfo["notification_name"] as? String) ?? ""
    self.title = (userInfo["title"] as? String) ?? ""
    self.message = (userInfo["message"] as? String) ?? ""
    self.logId = (userInfo["log_id"] as? String) ?? ""
  }
}
