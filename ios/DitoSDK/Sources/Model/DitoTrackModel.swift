import Foundation

struct DitoTrackModel: Codable {

  let action: String
  let reference: String
  let status: Int

  private enum CodingKeys: String, CodingKey {
    case action
    case reference
    case status
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    action = try values.decodeIfPresent(String.self, forKey: .action)
      .unwrappedValue
    reference = try values.decodeIfPresent(String.self, forKey: .reference)
      .unwrappedValue
    status = try values.decodeIfPresent(Int.self, forKey: .status)
      .unwrappedValue
  }
}
