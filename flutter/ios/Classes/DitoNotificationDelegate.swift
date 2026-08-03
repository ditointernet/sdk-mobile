import DitoSDK
import FirebaseMessaging
import UIKit
import UserNotifications

private let ditoPushDebugTag = "[DitoPush]"
private let fcmTokenUserDefaultsKey = "FCMToken"
private let fcmTokenFetchTimeoutSeconds: TimeInterval = 8

final class DitoNotificationDelegate: NSObject, MessagingDelegate, UNUserNotificationCenterDelegate {
  private weak var originalDelegate: UNUserNotificationCenterDelegate?
  private let lock = NSLock()

  static let shared = DitoNotificationDelegate()

  private override init() {
    super.init()
  }

  static func nestedPayload(_ value: Any?) -> [AnyHashable: Any]? {
    if let dict = value as? [AnyHashable: Any] {
      return dict
    }
    if let dict = value as? [String: Any] {
      return Dictionary(uniqueKeysWithValues: dict.map { (AnyHashable($0.key), $0.value) })
    }
    return nil
  }

  static func normalizedDitoUserInfo(_ userInfo: [AnyHashable: Any]) -> [AnyHashable: Any] {
    var merged = userInfo
    for nestedKey in ["data", "gcm"] {
      guard let nested = nestedPayload(userInfo[AnyHashable(nestedKey)] ?? userInfo[nestedKey]) else {
        continue
      }
      for (key, value) in nested where merged[key] == nil {
        merged[key] = value
      }
    }
    return merged
  }

  static func channelFromUserInfo(_ userInfo: [AnyHashable: Any]) -> String? {
    if let data = nestedPayload(userInfo[AnyHashable("data")] ?? userInfo["data"]) {
      if let channel = data[AnyHashable("channel")] as? String ?? data["channel"] as? String {
        return channel
      }
    }
    return userInfo[AnyHashable("channel")] as? String ?? userInfo["channel"] as? String
  }

  static func isDitoChannel(_ userInfo: [AnyHashable: Any]) -> Bool {
    channelFromUserInfo(userInfo) == "DITO"
  }

  static func ensureDitoConfigured() {
    _ = Dito.shared
    let bundle = Bundle.main
    let appKey =
      (bundle.object(forInfoDictionaryKey: "AppKey") as? String)
      ?? (bundle.object(forInfoDictionaryKey: "ApiKey") as? String)
      ?? (bundle.object(forInfoDictionaryKey: "API_KEY") as? String)
      ?? ""
    let appSecret =
      (bundle.object(forInfoDictionaryKey: "AppSecret") as? String)
      ?? (bundle.object(forInfoDictionaryKey: "ApiSecret") as? String)
      ?? (bundle.object(forInfoDictionaryKey: "API_SECRET") as? String)
      ?? ""
    if !appKey.isEmpty, !appSecret.isEmpty {
      Dito.configure(appKey: appKey, appSecret: appSecret)
    } else if !appKey.isEmpty {
      Dito.configure(apiKey: appKey, bundleId: bundle.bundleIdentifier ?? "")
    } else {
      Dito.shared.configure()
    }
  }

  private func logPush(context: String, userInfo: [AnyHashable: Any]) {
    let channel = Self.channelFromUserInfo(userInfo) ?? "(nil)"
    let isDito = Self.isDitoChannel(userInfo)
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
    let cached = UserDefaults.standard.string(forKey: fcmTokenUserDefaultsKey)
    if let cached = cached, !cached.isEmpty {
      return cached
    }
    return nil
  }

  private func cacheFcmToken(_ token: String?) {
    guard let token = token, !token.isEmpty else { return }
    UserDefaults.standard.set(token, forKey: fcmTokenUserDefaultsKey)
  }

  private func fetchFcmTokenIfNeeded(completion: @escaping (String?) -> Void) {
    let completionLock = NSLock()
    var completed = false
    let finish: (String?) -> Void = { token in
      completionLock.lock()
      defer { completionLock.unlock() }
      guard !completed else { return }
      completed = true
      completion(token)
    }

    let timeoutWork = DispatchWorkItem {
      finish(nil)
    }
    DispatchQueue.global().asyncAfter(
      deadline: .now() + fcmTokenFetchTimeoutSeconds,
      execute: timeoutWork
    )

    Messaging.messaging().token { [weak self] token, _ in
      timeoutWork.cancel()
      self?.cacheFcmToken(token)
      finish(token)
    }
  }

  private func trimmedString(from raw: Any?) -> String? {
    guard let raw else { return nil }
    if let string = raw as? String {
      let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }
    if let number = raw as? NSNumber {
      let trimmed = number.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }
    return nil
  }

  private func stringField(_ userInfo: [AnyHashable: Any], key: String) -> String {
    let hashKey = AnyHashable(key)
    if let data = Self.nestedPayload(userInfo[AnyHashable("data")] ?? userInfo["data"]),
       let value = trimmedString(from: data[hashKey] ?? data[key]) {
      return value
    }
    if let value = trimmedString(from: userInfo[hashKey] ?? userInfo[key]) {
      return value
    }
    return ""
  }

  private func deliverReceiveIfNeeded(
    userInfo: [AnyHashable: Any],
    fetchCompletion: ((UIBackgroundFetchResult) -> Void)? = nil
  ) {
    Self.ensureDitoConfigured()
    let normalized = Self.normalizedDitoUserInfo(userInfo)

    guard Self.isDitoChannel(normalized) else {
      fetchCompletion?(.noData)
      return
    }

    let notificationId = stringField(normalized, key: "notification")
    let logId = stringField(normalized, key: "log_id")
    guard Dito.shouldDeliverReceiveNotification(notification: notificationId, logId: logId) else {
      fetchCompletion?(.newData)
      return
    }

    let invokeReceive: (String) -> Void = { token in
      let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else {
        fetchCompletion?(.noData)
        return
      }
      Dito.notificationReceived(userInfo: normalized, token: trimmed) { result in
        guard let fetchCompletion else { return }
        switch result {
        case .success:
          fetchCompletion(.newData)
        case .failure:
          fetchCompletion(.failed)
        }
      }
    }

    if let cached = cachedFcmToken() {
      invokeReceive(cached)
      return
    }

    fetchFcmTokenIfNeeded { token in
      guard let token, !token.isEmpty else {
        fetchCompletion?(.noData)
        return
      }
      guard Dito.shouldDeliverReceiveNotification(notification: notificationId, logId: logId) else {
        fetchCompletion?(.newData)
        return
      }
      invokeReceive(token)
    }
  }

  private func notifyFirebase(userInfo: [AnyHashable: Any]) {
    Messaging.messaging().appDidReceiveMessage(userInfo)
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
    logPush(context: "Push received (background)", userInfo: userInfo)
    notifyFirebase(userInfo: userInfo)
    deliverReceiveIfNeeded(userInfo: userInfo, fetchCompletion: completionHandler)
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    logPush(context: "Push received (foreground)", userInfo: userInfo)
    notifyFirebase(userInfo: userInfo)
    deliverReceiveIfNeeded(userInfo: userInfo)
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
    let userInfo = response.notification.request.content.userInfo
    logPush(context: "Push tap received", userInfo: userInfo)
    notifyFirebase(userInfo: userInfo)
    let normalized = Self.normalizedDitoUserInfo(userInfo)
    if Self.isDitoChannel(normalized) {
      deliverReceiveIfNeeded(userInfo: userInfo)
      // response.actionIdentifier é o único lugar de onde sai qual botão foi tocado.
      // O SDK descarta os identifiers de default/dismiss do sistema, então um toque no
      // corpo continua chegando no Dart como clique comum.
      DitoSdkPlugin.didReceiveNotificationClick(
        userInfo: userInfo,
        actionIdentifier: response.actionIdentifier
      )
    }
    if let orig = originalDelegate, orig.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
      orig.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
    } else {
      completionHandler()
    }
  }
}
