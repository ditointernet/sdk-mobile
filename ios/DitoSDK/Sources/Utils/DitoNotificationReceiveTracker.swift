import Foundation

enum DitoNotificationReceiveTracker {
  private static let storageKey = "DitoDeliveredReceivePushKeys"
  private static let lock = NSLock()
  private static let maxStoredKeys = 500

  static func deliveryKey(notification: String, logId: String) -> String {
    let nid = notification.trimmingCharacters(in: .whitespacesAndNewlines)
    let lid = logId.trimmingCharacters(in: .whitespacesAndNewlines)
    if nid.isEmpty && lid.isEmpty {
      return ""
    }
    return "\(nid)|\(lid)"
  }

  static func wasDelivered(notification: String, logId: String) -> Bool {
    let key = deliveryKey(notification: notification, logId: logId)
    guard !key.isEmpty else { return false }
    lock.lock()
    defer { lock.unlock() }
    return UserDefaults.standard.stringArray(forKey: storageKey)?.contains(key) ?? false
  }

  static func markDelivered(notification: String, logId: String) {
    let key = deliveryKey(notification: notification, logId: logId)
    guard !key.isEmpty else { return }
    lock.lock()
    defer { lock.unlock() }
    var keys = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
    guard !keys.contains(key) else { return }
    keys.append(key)
    if keys.count > maxStoredKeys {
      keys = Array(keys.suffix(maxStoredKeys))
    }
    UserDefaults.standard.set(keys, forKey: storageKey)
  }

  #if DEBUG
  static func resetForTests() {
    lock.lock()
    defer { lock.unlock() }
    UserDefaults.standard.removeObject(forKey: storageKey)
  }
  #endif
}
