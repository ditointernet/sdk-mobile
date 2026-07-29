import Foundation

struct DitoNotificationReceivePending: Codable, Sendable {
  let userId: String
  let token: String
  let notification: String
  let logId: String
  let notificationName: String
}
