import CoreData
import Foundation

struct DitoNotificationRegisterDataManager {

  @discardableResult
  func save(with json: String?, retry: Int16 = 1, anonymous: Bool = false) -> Bool {

    let newNotificationRegister = NotificationDefaults(
      retry: retry,
      json: json,
      anonymous: anonymous ? true : nil
    )
    UserDefaults.notificationRegister = newNotificationRegister

    return true
  }

  @discardableResult
  func update(ifMatching expected: NotificationDefaults, retry: Int16) -> Bool {
    guard var pending = fetch, pending == expected else { return false }
    pending.retry = retry
    UserDefaults.notificationRegister = pending
    return true
  }

  var fetch: NotificationDefaults? {
    guard let notificationRegisterSaved = UserDefaults.notificationRegister
    else { return nil }
    return notificationRegisterSaved
  }

  @discardableResult
  func delete(ifMatching expected: NotificationDefaults) -> Bool {
    guard fetch == expected else { return false }
    return delete()
  }

  @discardableResult
  func delete() -> Bool {
    UserDefaults.notificationRegister = nil
    return true
  }
}
