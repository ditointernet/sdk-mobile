import Foundation

struct DitoTokenRequest: Codable {

  let platformApiKey: String
  let sha1Signature: String
  let token: String
  let platform: String = "Apple iPhone"
  let idType: String = "id"
  let encoding: String = "base64"

  /// Initializes a token request for Firebase Cloud Messaging
  /// - Parameters:
  ///   - platformApiKey: The Dito platform API key
  ///   - sha1Signature: The SHA1 signature for authentication
  ///   - token: The FCM token from Firebase Messaging
  init(platformApiKey: String, sha1Signature: String, token: String) {
    self.platformApiKey = platformApiKey
    self.sha1Signature = sha1Signature
    self.token = token
  }

  enum CodingKeys: String, CodingKey {
    case platformApiKey = "platform_api_key"
    case sha1Signature = "sha1_signature"
    case token
    case platform
    case idType = "id_type"
    case encoding
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(platformApiKey, forKey: .platformApiKey)
    try container.encode(sha1Signature, forKey: .sha1Signature)
    try container.encode(token, forKey: .token)
    try container.encode(platform, forKey: .platform)
    try container.encode(idType, forKey: .idType)
    try container.encode(encoding, forKey: .encoding)
  }
}
