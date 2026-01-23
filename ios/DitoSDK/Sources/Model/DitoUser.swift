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
    try container.encode(name, forKey: .name)
    try container.encode(gender, forKey: .gender)
    try container.encode(email, forKey: .email)
    try container.encode(birthday, forKey: .birthday)
    try container.encode(location, forKey: .location)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(data, forKey: .data)
  }
}
