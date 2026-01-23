import Foundation

struct DitoTokenModel: Codable {

  let token: String

  private enum CodingKeys: String, CodingKey {
    case token
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    token = try values.decodeIfPresent(String.self, forKey: .token)
      .unwrappedValue
  }
}
