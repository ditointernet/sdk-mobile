import CoreData
import Foundation

struct DitoNotificationRegisterDataManager {

  // The retry and `processToken` read-compare-write this single slot from different threads.
  private static let lock = NSLock()

  @discardableResult
  func save(with json: String?, retry: Int16 = 1, anonymous: Bool = false) -> Bool {

    let newNotificationRegister = NotificationDefaults(
      retry: retry,
      json: json,
      anonymous: anonymous ? true : nil
    )
    Self.lock.lock()
    defer { Self.lock.unlock() }
    UserDefaults.notificationRegister = newNotificationRegister

    return true
  }

  @discardableResult
  func update(ifMatching expected: NotificationDefaults, retry: Int16) -> Bool {
    Self.lock.lock()
    defer { Self.lock.unlock() }
    guard var pending = UserDefaults.notificationRegister, pending == expected else { return false }
    pending.retry = retry
    UserDefaults.notificationRegister = pending
    return true
  }

  var fetch: NotificationDefaults? {
    Self.lock.lock()
    defer { Self.lock.unlock() }
    return UserDefaults.notificationRegister
  }

  @discardableResult
  func delete(ifMatching expected: NotificationDefaults) -> Bool {
    Self.lock.lock()
    defer { Self.lock.unlock() }
    guard UserDefaults.notificationRegister == expected else { return false }
    UserDefaults.notificationRegister = nil
    return true
  }

  @discardableResult
  func delete() -> Bool {
    Self.lock.lock()
    defer { Self.lock.unlock() }
    UserDefaults.notificationRegister = nil
    return true
  }
}
