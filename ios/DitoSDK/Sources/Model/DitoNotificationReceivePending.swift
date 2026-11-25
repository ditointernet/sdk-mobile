import Foundation

struct DitoNotificationReceivePending: Codable, Sendable {
  let userId: String
  let token: String
  let notification: String
  let logId: String
  let notificationName: String
  /// ISO time the push arrived; optional so rows queued before this field still decode (they go out with send time).
  var receivedAt: String? = nil
}
