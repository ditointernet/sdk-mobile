import Foundation

struct DitoEventRequest: Codable {

  let platformAppKey: String
  let sha1Signature: String
  let event: DitoEvent
  var networkName: String = "pt"
  var encoding: String = "base64"
  var idType: String = "id"

  init(platformAppKey: String, sha1Signature: String, event: DitoEvent) {
    self.platformAppKey = platformAppKey
    self.sha1Signature = sha1Signature
    self.event = event
  }

  enum CodingKeys: String, CodingKey {
    case platformAppKey = "platform_api_key"
    case sha1Signature = "sha1_signature"
    case event
    case networkName = "network_name"
    case encoding
    case idType = "id_type"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(platformAppKey, forKey: .platformAppKey)
    try container.encode(sha1Signature, forKey: .sha1Signature)
    let eventJSON = event.toString.unwrappedValue
    try container.encode(eventJSON, forKey: .event)
    try container.encode(networkName, forKey: .networkName)
    try container.encode(encoding, forKey: .encoding)
    try container.encode(idType, forKey: .idType)
  }
}
