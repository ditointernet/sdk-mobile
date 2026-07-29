import Foundation
import os.log

/// Which process emitted a push log line.
///
/// The Notification Service Extension runs in its own process, so its output does
/// not appear alongside the host app's. Tagging the source is what makes the two
/// streams correlatable in Console.app.
public enum DitoPushLogSource: String, Sendable {
  case app
  case notificationServiceExtension = "nse"
}

/// Which moment of a push's life a log line describes.
///
/// The app process emits a line both when a push arrives and when one is tapped;
/// without this field the two are indistinguishable, which is exactly the
/// distinction a delivery-versus-click investigation needs.
public enum DitoPushLogEvent: String, Sendable {
  case received
  case clicked
}

/// Single-line, greppable dump of an incoming push payload.
///
/// Disabled by default. Enable it either programmatically (`DitoPushDebugLog.isEnabled`)
/// or, for the extension process where the host app cannot reach in, by adding a
/// `DitoPushDebugLog` boolean to the extension's Info.plist.
///
/// Every line has the shape:
///
///     DITO_PUSH_PAYLOAD {"source":"nse","notification":"…","image":"…", …}
///
/// so it can be extracted with a plain `grep DITO_PUSH_PAYLOAD` and piped to `jq`.
public enum DitoPushDebugLog {

  /// Stable prefix. Do not change: tooling and support scripts grep for it.
  public static let prefix = "DITO_PUSH_PAYLOAD"

  static let infoPlistKey = "DitoPushDebugLog"

  private static let log = OSLog(subsystem: "br.com.dito.sdk", category: "push")

  /// Truncation ceiling for the raw payload. The push budget is ~4KB, so this
  /// keeps a full payload while bounding a pathological one.
  static let maxRawLength = 4096

  /// Prefix of the companion raw-payload line. Emitted privately, so it only
  /// materialises for whoever has enabled private-data logging on the device.
  public static let rawPrefix = "DITO_PUSH_RAW"

  /// Payload keys carrying who the user is. Redacted even inside the private
  /// line: a support log should never be the thing that leaks an identity.
  static let redactedKeys: Set<String> = ["user_id", "identifier", "reference", "token"]

  private static let overrideLock = NSLock()
  nonisolated(unsafe) private static var overrideEnabled: Bool?

  /// Whether payload dumping is on.
  ///
  /// Resolution order: explicit override, then the `DitoPushDebugLog` Info.plist
  /// flag of the *running* bundle, then the existing `EnabledDebug` launch argument.
  public static var isEnabled: Bool {
    get {
      overrideLock.lock()
      let override = overrideEnabled
      overrideLock.unlock()
      if let override { return override }
      if let flag = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? Bool { return flag }
      return ProcessInfo.processInfo.arguments.contains("EnabledDebug")
    }
    set {
      overrideLock.lock()
      overrideEnabled = newValue
      overrideLock.unlock()
    }
  }

  /// Restores flag resolution to its Info.plist / launch-argument default.
  public static func resetEnabledOverride() {
    overrideLock.lock()
    overrideEnabled = nil
    overrideLock.unlock()
  }

  /// Emits the summary line, plus the raw payload as a second, private line.
  /// No-op when disabled.
  ///
  /// The split is deliberate: the summary is derived, carries no identity and
  /// stays public so `grep DITO_PUSH_PAYLOAD` keeps working, while the untouched
  /// payload goes out as `%{private}@` and shows up as `<private>` unless private
  /// data is explicitly enabled on the device. `os_log` output is persisted and
  /// travels in a sysdiagnose, so it is not a place for a user id.
  public static func dump(
    event: DitoPushLogEvent,
    source: DitoPushLogSource,
    userInfo: [AnyHashable: Any]
  ) {
    guard isEnabled else { return }
    os_log("%{public}@", log: log, type: .info, line(event: event, source: source, userInfo: userInfo))
    os_log("%{public}@ %{private}@", log: log, type: .debug, rawPrefix, rawLine(userInfo: userInfo))
  }

  /// Builds the summary line. Exposed for tests so the format stays pinned.
  static func line(
    event: DitoPushLogEvent,
    source: DitoPushLogSource,
    userInfo: [AnyHashable: Any]
  ) -> String {
    let payload = DitoRichPushPayload(userInfo: userInfo)

    var summary: [String: Any] = [
      "event": event.rawValue,
      "source": source.rawValue,
      "notification": DitoRichPushPayload.stringValue(userInfo, key: "notification") ?? "",
      "log_id": DitoRichPushPayload.stringValue(userInfo, key: "log_id") ?? "",
      "has_image": payload.imageURL != nil,
      "action_ids": payload.actions.map(\.id),
      "custom_data_keys": payload.customData.keys.sorted(),
      "has_legacy_data": DitoRichPushPayload.rawValue(userInfo, key: "data") != nil,
    ]
    if let imageURL = payload.imageURL {
      summary["image"] = imageURL.absoluteString
    }

    return "\(prefix) \(compactJSON(summary))"
  }

  /// JSON-safe, single-line rendering of the payload, with identity redacted.
  ///
  /// Exposed for tests so the redaction stays pinned. Only ever logged privately.
  static func rawLine(userInfo: [AnyHashable: Any]) -> String {
    let rendered = compactJSON(sanitized(userInfo))
    return rendered.count > maxRawLength
      ? String(rendered.prefix(maxRawLength)) + "…<truncated>"
      : rendered
  }

  private static func compactJSON(_ object: Any) -> String {
    guard
      JSONSerialization.isValidJSONObject(object),
      let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
      let string = String(data: data, encoding: .utf8)
    else {
      // Never let logging throw; fall back to a one-line description.
      return "\"\(String(describing: object).replacingOccurrences(of: "\n", with: " "))\""
    }
    return string
  }

  /// Coerces an arbitrary `userInfo` into something `JSONSerialization` accepts,
  /// redacting identity along the way — including inside nested `data` payloads,
  /// since the recursion reaches them too.
  ///
  /// An empty value is left as-is rather than redacted: there is nothing to leak,
  /// and "this key arrived empty" is usually the whole point of reading the log.
  private static func sanitized(_ value: Any) -> Any {
    switch value {
    case let dictionary as [AnyHashable: Any]:
      var result: [String: Any] = [:]
      for (key, nested) in dictionary {
        let name = "\(key)"
        if redactedKeys.contains(name), !isEmptyValue(nested) {
          result[name] = "<redacted>"
        } else {
          result[name] = sanitized(nested)
        }
      }
      return result
    case let array as [Any]:
      return array.map(sanitized)
    case let string as String:
      return string
    case let number as NSNumber:
      return number
    case is NSNull:
      return NSNull()
    default:
      return String(describing: value)
    }
  }

  private static func isEmptyValue(_ value: Any) -> Bool {
    if value is NSNull { return true }
    if let string = value as? String {
      return string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    return false
  }
}
