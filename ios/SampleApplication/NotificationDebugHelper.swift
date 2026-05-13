import DitoSDK
import Foundation

class NotificationDebugHelper {

  private static let debugDirName = "dito_notifications_debug"
  private static let maxFiles = 10
  private static let filePrefix = "notification_"
  private static let supportedExtensions = ["json", "plist", "txt"]

  static func saveNotification(_ userInfo: [AnyHashable: Any]) {
    do {
      let debugDir = getDebugDirectory()
      try FileManager.default.createDirectory(at: debugDir, withIntermediateDirectories: true)

      let timestamp = DateFormatter.timestampFormatter.string(from: Date())
      let stem = "\(filePrefix)\(timestamp)"
      let normalizedData = jsonCompatibleDictionary(userInfo)
      let payload: [String: Any] = [
        "timestamp": timestamp,
        "data": normalizedData,
      ]

      let fileURL: URL
      if JSONSerialization.isValidJSONObject(payload),
        let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
      {
        fileURL = debugDir.appendingPathComponent("\(stem).json")
        try jsonData.write(to: fileURL)
        print("✅ NotificationDebugHelper: Notification saved to \(fileURL.path)")
      } else if let plistData = try? PropertyListSerialization.data(
        fromPropertyList: propertyListCompatible(payload),
        format: .binary,
        options: 0
      ) {
        fileURL = debugDir.appendingPathComponent("\(stem).plist")
        try plistData.write(to: fileURL)
        print("✅ NotificationDebugHelper: Notification saved (plist) to \(fileURL.path)")
      } else {
        let text = String(describing: userInfo)
        let maxLen = 64_000
        let clipped = text.count > maxLen ? String(text.prefix(maxLen)) + "\n…(truncado)" : text
        fileURL = debugDir.appendingPathComponent("\(stem).txt")
        try clipped.data(using: .utf8)?.write(to: fileURL)
        print("✅ NotificationDebugHelper: Notification saved (txt fallback) to \(fileURL.path)")
      }

      cleanOldFiles(in: debugDir)
    } catch {
      print("❌ NotificationDebugHelper: Error saving notification: \(error.localizedDescription)")
    }
  }

  static func getAllNotifications() -> [[String: Any]] {
    let debugDir = getDebugDirectory()
    guard FileManager.default.fileExists(atPath: debugDir.path) else {
      return []
    }

    do {
      let files = try FileManager.default.contentsOfDirectory(
        at: debugDir,
        includingPropertiesForKeys: [.creationDateKey],
        options: []
      )
      .filter { url in
        guard url.lastPathComponent.hasPrefix(filePrefix) else { return false }
        return supportedExtensions.contains(url.pathExtension.lowercased())
      }
      .sorted { url1, url2 in
        let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
        let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
        return date1 > date2
      }

      var notifications: [[String: Any]] = []
      for fileURL in files {
        if let parsed = parseNotificationFile(at: fileURL) {
          notifications.append(parsed)
        }
      }
      return notifications
    } catch {
      print("❌ NotificationDebugHelper: Error reading notifications: \(error.localizedDescription)")
      return []
    }
  }

  static func getLatestNotification() -> [String: Any]? {
    getAllNotifications().first
  }

  static func readNotificationJSON(_ notification: [String: Any]) -> String {
    do {
      let jsonData = try JSONSerialization.data(withJSONObject: notification, options: .prettyPrinted)
      return String(data: jsonData, encoding: .utf8) ?? "{}"
    } catch {
      print("❌ NotificationDebugHelper: Error converting to JSON: \(error.localizedDescription)")
      return "{}"
    }
  }

  static func simulateNotification(_ payload: [String: Any], token: String) {
    let bridged = payload.reduce(into: [AnyHashable: Any]()) { result, pair in
      result[AnyHashable(pair.key)] = pair.value
    }
    Dito.notificationReceived(userInfo: bridged, token: token)
    print("✅ NotificationDebugHelper: Notification simulated")
  }

  static func clearAllNotifications() {
    let debugDir = getDebugDirectory()
    do {
      let files = try FileManager.default.contentsOfDirectory(at: debugDir, includingPropertiesForKeys: nil, options: [])
        .filter { url in
          guard url.lastPathComponent.hasPrefix(filePrefix) else { return false }
          return supportedExtensions.contains(url.pathExtension.lowercased())
        }

      for fileURL in files {
        try? FileManager.default.removeItem(at: fileURL)
      }

      print("✅ NotificationDebugHelper: Cleared \(files.count) notifications")
    } catch {
      print("❌ NotificationDebugHelper: Error clearing notifications: \(error.localizedDescription)")
    }
  }

  private static func getDebugDirectory() -> URL {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documentsPath.appendingPathComponent(debugDirName)
  }

  private static func parseNotificationFile(at fileURL: URL) -> [String: Any]? {
    let ext = fileURL.pathExtension.lowercased()
    switch ext {
    case "json":
      guard let data = try? Data(contentsOf: fileURL),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
      else { return nil }
      return json
    case "plist":
      guard let data = try? Data(contentsOf: fileURL),
        let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
      else { return nil }
      return obj as? [String: Any]
    case "txt":
      guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
      let stem = fileURL.deletingPathExtension().lastPathComponent
      let ts = stem.hasPrefix(filePrefix) ? String(stem.dropFirst(filePrefix.count)) : stem
      return [
        "timestamp": ts,
        "format": "txt",
        "raw": text,
      ]
    default:
      return nil
    }
  }

  private static func cleanOldFiles(in directory: URL) {
    do {
      let files = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.creationDateKey],
        options: []
      )
      .filter { url in
        guard url.lastPathComponent.hasPrefix(filePrefix) else { return false }
        return supportedExtensions.contains(url.pathExtension.lowercased())
      }
      .sorted { url1, url2 in
        let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
        let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
        return date1 > date2
      }

      if files.count > maxFiles {
        for fileURL in files.dropFirst(maxFiles) {
          try? FileManager.default.removeItem(at: fileURL)
          print("🗑️ NotificationDebugHelper: Deleted old notification file: \(fileURL.lastPathComponent)")
        }
      }
    } catch {
      print("❌ NotificationDebugHelper: Error cleaning old files: \(error.localizedDescription)")
    }
  }

  private static func jsonCompatibleDictionary(_ userInfo: [AnyHashable: Any]) -> [String: Any] {
    var result: [String: Any] = [:]
    for (key, value) in userInfo {
      result["\(key)"] = jsonCompatibleValue(value)
    }
    return result
  }

  private static func jsonCompatibleValue(_ value: Any) -> Any {
    switch value {
    case let s as String:
      return s
    case let n as NSNumber:
      return n
    case let b as Bool:
      return b
    case is NSNull:
      return NSNull()
    case let dict as [AnyHashable: Any]:
      return jsonCompatibleDictionary(dict)
    case let dict as [String: Any]:
      var out: [String: Any] = [:]
      for (k, v) in dict {
        out[k] = jsonCompatibleValue(v)
      }
      return out
    case let arr as [Any]:
      return arr.map { jsonCompatibleValue($0) }
    case let data as Data:
      return data.base64EncodedString()
    case let date as Date:
      return ISO8601DateFormatter().string(from: date)
    default:
      return String(describing: value)
    }
  }

  private static func propertyListCompatible(_ value: Any) -> Any {
    switch value {
    case let s as String:
      return s as NSString
    case let n as NSNumber:
      return n
    case let b as Bool:
      return NSNumber(value: b)
    case is NSNull:
      return "null" as NSString
    case let dict as [String: Any]:
      let out = NSMutableDictionary()
      for (k, v) in dict {
        out[k] = propertyListCompatible(v)
      }
      return out
    case let arr as [Any]:
      return arr.map { propertyListCompatible($0) } as NSArray
    case let data as Data:
      return data as NSData
    case let date as Date:
      return date as NSDate
    default:
      return String(describing: value) as NSString
    }
  }
}

extension DateFormatter {
  static let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    return formatter
  }()
}
