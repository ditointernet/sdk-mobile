import Foundation

struct DitoIdentifyModel: Codable {

  let reference: String
  let signedRequest: String
  let status: Int

  private enum RootKeys: String, CodingKey {
    case data
  }

  private enum DataKeys: String, CodingKey {
    case reference
    case signedRequest = "signed_request"
    case status
  }

  init(from decoder: Decoder) throws {
    let rootContainer = try decoder.container(keyedBy: RootKeys.self)
    let dataContainer = try rootContainer.nestedContainer(keyedBy: DataKeys.self, forKey: .data)

    reference = try dataContainer.decodeIfPresent(String.self, forKey: .reference)
      .unwrappedValue
    signedRequest = try dataContainer.decodeIfPresent(
      String.self,
      forKey: .signedRequest
    ).unwrappedValue
    status = try dataContainer.decodeIfPresent(Int.self, forKey: .status)
      .unwrappedValue
  }
}
