import Foundation

struct DitoNotificationOpenRequest: Codable {

  let platformAppKey: String
  let sha1Signature: String
  let data: DitoDataNotification
  let channelType: String = "mobile"

  init(
    platformAppKey: String,
    sha1Signature: String,
    data: DitoDataNotification
  ) {

    self.platformAppKey = platformAppKey
    self.sha1Signature = sha1Signature
    self.data = data
  }

  enum CodingKeys: String, CodingKey {
    case platformAppKey = "platform_api_key"
    case sha1Signature = "sha1_signature"
    case data
    case channelType = "channel_type"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(platformAppKey, forKey: .platformAppKey)
    try container.encode(sha1Signature, forKey: .sha1Signature)
    try container.encode(data, forKey: .data)
    try container.encode(channelType, forKey: .channelType)
  }
}
