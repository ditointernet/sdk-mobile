import Foundation

struct DitoNotificationReadModel: Codable {

  let notification: String

  private enum CodingKeys: String, CodingKey {
    case notification
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    notification = try values.decodeIfPresent(
      String.self,
      forKey: .notification
    ).unwrappedValue
  }
}
