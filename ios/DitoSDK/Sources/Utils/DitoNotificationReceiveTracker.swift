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

  /// Deliveries claimed but not yet answered by the ingest.
  ///
  /// Only ever touched under `lock`.
  nonisolated(unsafe) private static var inFlight: Set<String> = []

  static func wasDelivered(notification: String, logId: String) -> Bool {
    let key = deliveryKey(notification: notification, logId: logId)
    guard !key.isEmpty else { return false }
    lock.lock()
    defer { lock.unlock() }
    return storedKeys().contains(key)
  }

  /// Claims the delivery for the caller, atomically. Exactly one concurrent caller gets `true`.
  ///
  /// `wasDelivered` followed by `markDelivered` was not enough to dedupe: there is an `await` on the
  /// network between the two, and with the app in the foreground `willPresent` and
  /// `didReceiveRemoteNotification` both drive this path for the same push — so both calls passed
  /// the check and both sent the event. Claiming closes that window.
  ///
  /// A push with neither identifier cannot be deduplicated at all, so it is always allowed through:
  /// sending twice is a lesser failure than never sending.
  static func claimDelivery(notification: String, logId: String) -> Bool {
    let key = deliveryKey(notification: notification, logId: logId)
    guard !key.isEmpty else { return true }
    lock.lock()
    defer { lock.unlock() }
    guard !storedKeys().contains(key), !inFlight.contains(key) else { return false }
    inFlight.insert(key)
    return true
  }

  /// Gives up a claim without marking the delivery as done, so a retry can take it.
  static func releaseClaim(notification: String, logId: String) {
    let key = deliveryKey(notification: notification, logId: logId)
    guard !key.isEmpty else { return }
    lock.lock()
    defer { lock.unlock() }
    inFlight.remove(key)
  }

  static func markDelivered(notification: String, logId: String) {
    let key = deliveryKey(notification: notification, logId: logId)
    guard !key.isEmpty else { return }
    lock.lock()
    defer { lock.unlock() }
    inFlight.remove(key)
    var keys = storedKeys()
    guard !keys.contains(key) else { return }
    keys.append(key)
    if keys.count > maxStoredKeys {
      keys = Array(keys.suffix(maxStoredKeys))
    }
    UserDefaults.standard.set(keys, forKey: storageKey)
  }

  /// Persisted delivered keys. Callers must already hold `lock` — `NSLock` is not recursive.
  private static func storedKeys() -> [String] {
    UserDefaults.standard.stringArray(forKey: storageKey) ?? []
  }

  #if DEBUG
  static func resetForTests() {
    lock.lock()
    defer { lock.unlock() }
    inFlight.removeAll()
    UserDefaults.standard.removeObject(forKey: storageKey)
  }
  #endif
}
