import Foundation

struct DitoIdentifyModel: Codable {

  let reference: String
  let signedRequest: String
  let status: Int

  private enum CodingKeys: String, CodingKey {
    case reference
    case signedRequest = "signed_request"
    case status
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    reference = try values.decodeIfPresent(String.self, forKey: .reference)
      .unwrappedValue
    signedRequest = try values.decodeIfPresent(
      String.self,
      forKey: .signedRequest
    ).unwrappedValue
    status = try values.decodeIfPresent(Int.self, forKey: .status)
      .unwrappedValue
  }
}
