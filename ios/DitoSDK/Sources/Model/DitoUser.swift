import Foundation

public struct DitoUser: Codable, Sendable {

  let name: String?
  let gender: String?
  let email: String?
  let birthday: String?
  let location: String?
  let createdAt: String?
  let data: String?

  public init(
    name: String? = nil,
    gender: DitoGender? = nil,
    email: String? = nil,
    birthday: Date? = nil,
    location: String? = nil,
    createdAt: Date? = nil,
    customData: Any? = nil
  ) {

    self.name = name
    self.gender = gender?.rawValue
    self.email = email?.validateEmail
    self.birthday = birthday?.formatToDitoDate
    self.location = location
    self.createdAt = Util.toDate(createdAt)
    self.data = Util.toString(from: customData)

  }

  enum CodingKeys: String, CodingKey {
    case name, gender, email, birthday, location, data
    case createdAt = "created_at"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(name, forKey: .name)
    try container.encodeIfPresent(gender, forKey: .gender)
    try container.encodeIfPresent(email, forKey: .email)
    try container.encodeIfPresent(birthday, forKey: .birthday)
    try container.encodeIfPresent(location, forKey: .location)
    try container.encodeIfPresent(createdAt, forKey: .createdAt)
    try container.encodeIfPresent(data, forKey: .data)
  }
}
