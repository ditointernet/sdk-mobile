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

  nonisolated(unsafe) private static var overrideEnabled: Bool?

  /// Whether payload dumping is on.
  ///
  /// Resolution order: explicit override, then the `DitoPushDebugLog` Info.plist
  /// flag of the *running* bundle, then the existing `EnabledDebug` launch argument.
  public static var isEnabled: Bool {
    get {
      if let overrideEnabled { return overrideEnabled }
      if let flag = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? Bool { return flag }
      return ProcessInfo.processInfo.arguments.contains("EnabledDebug")
    }
    set { overrideEnabled = newValue }
  }

  /// Restores flag resolution to its Info.plist / launch-argument default.
  public static func resetEnabledOverride() {
    overrideEnabled = nil
  }

  /// Emits one line describing `userInfo`. No-op when disabled.
  public static func dump(source: DitoPushLogSource, userInfo: [AnyHashable: Any]) {
    guard isEnabled else { return }
    os_log("%{public}@", log: log, type: .info, line(source: source, userInfo: userInfo))
  }

  /// Builds the log line. Exposed for tests so the format stays pinned.
  static func line(source: DitoPushLogSource, userInfo: [AnyHashable: Any]) -> String {
    let payload = DitoRichPushPayload(userInfo: userInfo)

    var summary: [String: Any] = [
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
    summary["raw"] = rawDescription(userInfo)

    return "\(prefix) \(compactJSON(summary))"
  }

  /// JSON-safe, single-line rendering of the untouched payload.
  private static func rawDescription(_ userInfo: [AnyHashable: Any]) -> String {
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

  /// Coerces an arbitrary `userInfo` into something `JSONSerialization` accepts.
  private static func sanitized(_ value: Any) -> Any {
    switch value {
    case let dictionary as [AnyHashable: Any]:
      var result: [String: Any] = [:]
      for (key, nested) in dictionary {
        result["\(key)"] = sanitized(nested)
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
}
