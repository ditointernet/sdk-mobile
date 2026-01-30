import Foundation

struct DitoEventRequest: Codable {

  let platformApiKey: String
  let sha1Signature: String
  let event: DitoEvent
  var networkName: String = "pt"
  var encoding: String = "base64"
  var idType: String = "id"

  init(platformApiKey: String, sha1Signature: String, event: DitoEvent) {
    self.platformApiKey = platformApiKey
    self.sha1Signature = sha1Signature
    self.event = event
  }

  enum CodingKeys: String, CodingKey {
    case platformApiKey = "platform_api_key"
    case sha1Signature = "sha1_signature"
    case event
    case networkName = "network_name"
    case encoding
    case idType = "id_type"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(platformApiKey, forKey: .platformApiKey)
    try container.encode(sha1Signature, forKey: .sha1Signature)
    try container.encode(event, forKey: .event)
    try container.encode(networkName, forKey: .networkName)
    try container.encode(encoding, forKey: .encoding)
    try container.encode(idType, forKey: .idType)
  }
}
