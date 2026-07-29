import Foundation

/// A single action button delivered with a Dito rich push.
///
/// The backend already resolves `link` for iOS, so there is exactly one link per
/// button and the SDK never has to pick between platforms.
public struct DitoPushAction: Equatable, Sendable {

  public let id: String
  public let label: String
  public let link: String

  public init(id: String, label: String, link: String) {
    self.id = id
    self.label = label
    self.link = link
  }
}

/// Limits guaranteed by the backend contract.
///
/// They are re-applied on the client because a push payload is untrusted input:
/// an out-of-contract payload must degrade, never crash.
enum DitoRichPushLimits {
  static let maxActions = 2
  static let maxLabelLength = 25
  static let maxActionIdLength = 32
  static let maxCustomDataKeys = 20
  static let maxCustomDataKeyLength = 40
  static let maxCustomDataValueLength = 250
}

/// The rich-push additions carried by a Dito FCM payload.
///
/// Every field is optional and additive: a campaign without buttons, image or
/// custom data produces an empty payload and the notification renders exactly as
/// it did before rich push existed.
public struct DitoRichPushPayload: Equatable, Sendable {

  public let imageURL: URL?
  public let actions: [DitoPushAction]
  public let customData: [String: String]

  public var hasActions: Bool { !actions.isEmpty }

  public var isEmpty: Bool {
    imageURL == nil && actions.isEmpty && customData.isEmpty
  }

  /// Deterministic category identifier for this set of buttons.
  ///
  /// Derived from the action ids so that the same campaign always maps to the
  /// same category, and two campaigns with different buttons never collide.
  /// Action ids are constrained to `^[a-z0-9_]{1,32}$` and there are at most two
  /// of them, so the result is bounded and filesystem/URL safe.
  public var categoryIdentifier: String? {
    guard !actions.isEmpty else { return nil }
    return "dito.actions." + actions.map(\.id).joined(separator: ".")
  }

  public init(imageURL: URL? = nil, actions: [DitoPushAction] = [], customData: [String: String] = [:]) {
    self.imageURL = imageURL
    self.actions = actions
    self.customData = customData
  }

  public init(userInfo: [AnyHashable: Any]) {
    self.imageURL = Self.parseImageURL(userInfo)
    self.actions = Self.parseActions(userInfo)
    self.customData = Self.parseCustomData(userInfo)
  }

  /// Returns the action matching a `UNNotificationResponse.actionIdentifier`.
  public func action(withId identifier: String) -> DitoPushAction? {
    actions.first { $0.id == identifier }
  }
}

// MARK: - Parsing

extension DitoRichPushPayload {

  /// Looks a key up at the top level and inside the `data` / `gcm` sub-dictionaries.
  ///
  /// Mirrors `DitoNotificationReceived.stringValue` so that both sides of the SDK
  /// agree on where a key may live, regardless of how the payload was delivered.
  static func rawValue(_ userInfo: [AnyHashable: Any], key: String) -> Any? {
    if let value = userInfo[key] { return value }
    if let data = userInfo["data"] as? [String: Any], let value = data[key] { return value }
    if let gcm = userInfo["gcm"] as? [String: Any], let value = gcm[key] { return value }
    return nil
  }

  static func stringValue(_ userInfo: [AnyHashable: Any], key: String) -> String? {
    guard let raw = rawValue(userInfo, key: key) else { return nil }
    let string: String
    if let value = raw as? String {
      string = value
    } else if let number = raw as? NSNumber {
      string = number.stringValue
    } else {
      return nil
    }
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  static func parseImageURL(_ userInfo: [AnyHashable: Any]) -> URL? {
    if let value = stringValue(userInfo, key: "image"), let url = URL(string: value), url.isRichPushDownloadable {
      return url
    }
    // `apns.fcm_options.image` surfaces as a `fcm_options` dictionary.
    if let options = rawValue(userInfo, key: "fcm_options") as? [String: Any],
       let value = options["image"] as? String,
       let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
       url.isRichPushDownloadable {
      return url
    }
    return nil
  }

  /// `data.actions` is a JSON *string*, not a nested object.
  static func parseActions(_ userInfo: [AnyHashable: Any]) -> [DitoPushAction] {
    guard let object = jsonObject(userInfo, key: "actions") else { return [] }
    guard let entries = object as? [[String: Any]] else { return [] }

    var actions: [DitoPushAction] = []
    var seenIds = Set<String>()

    for entry in entries {
      guard actions.count < DitoRichPushLimits.maxActions else { break }
      guard
        let id = (entry["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
        let label = (entry["label"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
        id.isValidDitoActionId,
        !label.isEmpty,
        !seenIds.contains(id)
      else { continue }

      let link = (entry["link"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      seenIds.insert(id)
      actions.append(
        DitoPushAction(
          id: id,
          label: String(label.prefix(DitoRichPushLimits.maxLabelLength)),
          link: link
        )
      )
    }
    return actions
  }

  /// `data.custom_data` is a JSON *string* whose variables are already substituted.
  static func parseCustomData(_ userInfo: [AnyHashable: Any]) -> [String: String] {
    guard let object = jsonObject(userInfo, key: "custom_data") else { return [:] }
    guard let dictionary = object as? [String: Any] else { return [:] }

    var result: [String: String] = [:]
    for key in dictionary.keys.sorted() {
      guard result.count < DitoRichPushLimits.maxCustomDataKeys else { break }
      guard key.isValidDitoCustomDataKey else { continue }
      guard let value = scalarString(dictionary[key]) else { continue }
      result[key] = String(value.prefix(DitoRichPushLimits.maxCustomDataValueLength))
    }
    return result
  }

  /// Decodes a value that is a JSON string, tolerating a pre-decoded object.
  private static func jsonObject(_ userInfo: [AnyHashable: Any], key: String) -> Any? {
    guard let raw = rawValue(userInfo, key: key) else { return nil }
    if let string = raw as? String {
      let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
      return try? JSONSerialization.jsonObject(with: data)
    }
    // Some delivery paths hand the value over already decoded.
    return raw
  }

  private static func scalarString(_ raw: Any?) -> String? {
    guard let raw else { return nil }
    if raw is NSNull { return nil }
    if let string = raw as? String { return string }
    if let number = raw as? NSNumber {
      if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() {
        return number.boolValue ? "true" : "false"
      }
      return number.stringValue
    }
    return nil
  }
}

// MARK: - Validation helpers

extension String {

  /// `^[a-z0-9_]{1,32}$`
  var isValidDitoActionId: Bool {
    isValidDitoIdentifier(maxLength: DitoRichPushLimits.maxActionIdLength)
  }

  /// `^[a-z0-9_]{1,40}$`
  var isValidDitoCustomDataKey: Bool {
    isValidDitoIdentifier(maxLength: DitoRichPushLimits.maxCustomDataKeyLength)
  }

  private func isValidDitoIdentifier(maxLength: Int) -> Bool {
    guard !isEmpty, count <= maxLength else { return false }
    return unicodeScalars.allSatisfy { scalar in
      (scalar >= "a" && scalar <= "z") || (scalar >= "0" && scalar <= "9") || scalar == "_"
    }
  }
}

extension URL {

  /// Only http(s) URLs are downloadable; anything else (file://, data:, …) is
  /// rejected so a malformed payload cannot make the extension read local files.
  var isRichPushDownloadable: Bool {
    guard let scheme = scheme?.lowercased() else { return false }
    return scheme == "http" || scheme == "https"
  }
}
