import Foundation

struct DitoSignupRequest: Codable {

  let platformApiKey: String
  let sha1Signature: String
  let userData: DitoUser?
  var encoding: String = "base64"

  enum CodingKeys: String, CodingKey {
    case platformApiKey = "platform_api_key"
    case sha1Signature = "sha1_signature"
    case userData = "user_data"
    case encoding
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(platformApiKey, forKey: .platformApiKey)
    try container.encode(sha1Signature, forKey: .sha1Signature)
    try container.encode(userData, forKey: .userData)
    try container.encode(encoding, forKey: .encoding)
  }
}
