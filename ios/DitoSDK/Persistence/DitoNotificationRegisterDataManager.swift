import CoreData
import Foundation

struct DitoNotificationRegisterDataManager {

  @discardableResult
  func save(with json: String?, retry: Int16 = 1) -> Bool {

    let newNotificationRegister = NotificationDefaults(
      retry: retry,
      json: json
    )
    UserDefaults.notificationRegister = newNotificationRegister

    return true
  }

  @discardableResult
  func update(id: NSManagedObjectID? = nil, retry: Int16) -> Bool {
    save(with: nil, retry: retry)
  }

  var fetch: NotificationDefaults? {
    guard let notificationRegisterSaved = UserDefaults.notificationRegister
    else { return nil }
    return notificationRegisterSaved
  }

  @discardableResult
  func delete() -> Bool {
    UserDefaults.notificationRegister = nil
    return true
  }
}
