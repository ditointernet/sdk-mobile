import DitoSDK
import FirebaseMessaging
import UIKit
import UserNotifications

private let ditoPushDebugTag = "[DitoPush]"

final class DitoNotificationDelegate: NSObject, MessagingDelegate, UNUserNotificationCenterDelegate {
  private weak var originalDelegate: UNUserNotificationCenterDelegate?
  private let lock = NSLock()

  static let shared = DitoNotificationDelegate()

  private override init() {
    super.init()
  }

  private func logPush(context: String, userInfo: [AnyHashable: Any]) {
    let channel = DitoPushUserInfo.channel(from: userInfo) ?? "(nil)"
    let isDito = DitoPushUserInfo.isDitoChannel(userInfo)
    print("\(ditoPushDebugTag) \(context) channel=\(channel) isDito=\(isDito)")
  }

  func install() {
    lock.lock()
    defer { lock.unlock() }
    let center = UNUserNotificationCenter.current()
    if center.delegate === self { return }
    originalDelegate = center.delegate as? NSObject as? UNUserNotificationCenterDelegate
    center.delegate = self
    print("\(ditoPushDebugTag) Delegate installed, push events will be logged with tag \(ditoPushDebugTag)")
  }

  func configurePush(application: UIApplication) {
    install()
    Messaging.messaging().delegate = self
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, _ in
      guard granted else { return }
      DispatchQueue.main.async {
        application.registerForRemoteNotifications()
      }
    }
  }

  private func cachedFcmToken() -> String? {
    let cached = UserDefaults.standard.string(forKey: "FCMToken")
    if let cached, !cached.isEmpty {
      return cached
    }
    return nil
  }

  private func handleDitoIfNeeded(userInfo: [AnyHashable: Any], fcmToken: String) {
    guard DitoPushUserInfo.isDitoChannel(userInfo) else { return }
    let trimmed = fcmToken.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    Dito.notificationReceived(userInfo: userInfo, token: trimmed)
  }

  private func cacheFcmToken(_ token: String?) {
    guard let token, !token.isEmpty else { return }
    UserDefaults.standard.set(token, forKey: "FCMToken")
  }

  private func shouldCallCompletionHandler() -> Bool {
    NSClassFromString("FLTFirebaseMessagingPlugin") == nil
  }

  private func notifyFirebase(userInfo: [AnyHashable: Any]) {
    Messaging.messaging().appDidReceiveMessage(userInfo)
  }

  private final class BackgroundTaskBox {
    var id: UIBackgroundTaskIdentifier = .invalid
  }

  private func runWithFcmToken(
    application: UIApplication,
    fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)? = nil,
    body: @escaping (String) -> Void
  ) {
    if let cached = cachedFcmToken(), !cached.isEmpty {
      body(cached)
      if let completionHandler, shouldCallCompletionHandler() {
        completionHandler(.newData)
      }
      return
    }

    let box = BackgroundTaskBox()
    if application.applicationState != .active {
      box.id = application.beginBackgroundTask(withName: "br.com.dito.fcm-token") {
        if box.id != .invalid {
          application.endBackgroundTask(box.id)
          box.id = .invalid
        }
      }
    }

    Messaging.messaging().token { [weak self] token, _ in
      self?.cacheFcmToken(token)
      let resolved = (token ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      if !resolved.isEmpty {
        body(resolved)
      }
      if box.id != .invalid {
        application.endBackgroundTask(box.id)
        box.id = .invalid
      }
      if let completionHandler, self?.shouldCallCompletionHandler() == true {
        completionHandler(resolved.isEmpty ? .noData : .newData)
      }
    }
  }
}

extension DitoNotificationDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    cacheFcmToken(fcmToken)
  }

  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    let merged = DitoPushUserInfo.merged(userInfo)
    logPush(context: "Push received (background)", userInfo: merged)
    notifyFirebase(userInfo: userInfo)
    if DitoPushUserInfo.isDitoChannel(merged) {
      runWithFcmToken(application: application, fetchCompletionHandler: completionHandler) { token in
        self.handleDitoIfNeeded(userInfo: merged, fcmToken: token)
      }
    } else if shouldCallCompletionHandler() {
      completionHandler(.noData)
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let merged = DitoPushUserInfo.merged(notification.request.content.userInfo)
    logPush(context: "Push received (foreground)", userInfo: merged)
    notifyFirebase(userInfo: notification.request.content.userInfo)
    if DitoPushUserInfo.isDitoChannel(merged) {
      runWithFcmToken(application: UIApplication.shared) { token in
        self.handleDitoIfNeeded(userInfo: merged, fcmToken: token)
      }
    }
    if let orig = originalDelegate, orig.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))) {
      orig.userNotificationCenter?(center, willPresent: notification, withCompletionHandler: completionHandler)
    } else {
      completionHandler([[.banner, .list, .sound, .badge]])
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let merged = DitoPushUserInfo.merged(response.notification.request.content.userInfo)
    logPush(context: "Push tap received", userInfo: merged)
    notifyFirebase(userInfo: response.notification.request.content.userInfo)
    if DitoPushUserInfo.isDitoChannel(merged) {
      _ = DitoSdkPlugin.didReceiveNotificationClick(userInfo: merged) { deeplink in
        DitoSdkPlugin.emitNotificationClickEvent(userInfo: merged, deeplink: deeplink)
      }
    }
    if let orig = originalDelegate, orig.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
      orig.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
    } else {
      completionHandler()
    }
  }
}

enum DitoPushUserInfo {
  static func merged(_ userInfo: [AnyHashable: Any]) -> [AnyHashable: Any] {
    var out: [AnyHashable: Any] = [:]
    for (k, v) in userInfo {
      out[k] = v
    }
    mergeDataField(into: &out, value: userInfo["data"])
    return out
  }

  private static func mergeDataField(into out: inout [AnyHashable: Any], value: Any?) {
    guard let value = value else { return }
    if let nested = value as? [AnyHashable: Any] {
      for (k, v) in nested where out[k] == nil {
        out[k] = v
      }
      return
    }
    if let nested = value as? [String: Any] {
      for (k, v) in nested {
        let key = k as AnyHashable
        if out[key] == nil { out[key] = v }
      }
      return
    }
    guard let string = value as? String,
          let data = string.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return
    }
    for (k, v) in obj {
      let key = k as AnyHashable
      if out[key] == nil { out[key] = v }
    }
  }

  static func channel(from userInfo: [AnyHashable: Any]) -> String? {
    if let ch = userInfo["channel"] as? String { return ch }
    if let data = userInfo["data"] as? [AnyHashable: Any], let ch = data["channel"] as? String { return ch }
    if let data = userInfo["data"] as? [String: Any], let ch = data["channel"] as? String { return ch }
    if let dataStr = userInfo["data"] as? String,
       let d = dataStr.data(using: .utf8),
       let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
       let ch = obj["channel"] as? String {
      return ch
    }
    return nil
  }

  static func isDitoChannel(_ userInfo: [AnyHashable: Any]) -> Bool {
    let ch = channel(from: userInfo) ?? ""
    return ch == "DITO" || ch.caseInsensitiveCompare("Dito") == .orderedSame
  }
}
