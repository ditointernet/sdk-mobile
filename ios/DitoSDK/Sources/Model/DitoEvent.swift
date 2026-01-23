import Foundation

public struct DitoEvent: Codable, Sendable {

  let action: String?
  let revenue: Double?
  let createdAt: String?
  let data: String?

  public init(
    action: String? = nil,
    revenue: Double? = nil,
    createdAt: Date? = nil,
    customData: Any? = nil
  ) {

    self.action = action?.formatToDitoString
    self.revenue = revenue
    self.createdAt = Util.toDate(createdAt)
    self.data = (customData != nil) ? Util.toString(from: customData) : nil
  }

  enum CodingKeys: String, CodingKey {
    case action, revenue, data
    case createdAt = "created_at"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(action, forKey: .action)
    try container.encode(revenue, forKey: .revenue)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(data, forKey: .data)
  }
}
