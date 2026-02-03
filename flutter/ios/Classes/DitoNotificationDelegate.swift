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
    let channel = channelFromUserInfo(userInfo) ?? "(nil)"
    let isDito = isDitoChannel(userInfo)
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

  private func channelFromUserInfo(_ userInfo: [AnyHashable: Any]) -> String? {
    if let data = userInfo["data"] as? [String: Any], let ch = data["channel"] as? String {
      return ch
    }
    return userInfo["channel"] as? String
  }

  private func isDitoChannel(_ userInfo: [AnyHashable: Any]) -> Bool {
    channelFromUserInfo(userInfo) == "DITO"
  }

  private func cachedFcmToken() -> String? {
    let cached = UserDefaults.standard.string(forKey: "FCMToken")
    if let cached = cached, !cached.isEmpty {
      return cached
    }
    return nil
  }

  private func handleDitoIfNeeded(userInfo: [AnyHashable: Any], fcmToken: String) {
    guard isDitoChannel(userInfo) else { return }
    Dito.notificationReceived(userInfo: userInfo, token: fcmToken)
  }

  private func cacheFcmToken(_ token: String?) {
    guard let token = token, !token.isEmpty else { return }
    UserDefaults.standard.set(token, forKey: "FCMToken")
  }

  private func fetchFcmTokenIfNeeded() {
    Messaging.messaging().token { [weak self] token, _ in
      self?.cacheFcmToken(token)
    }
  }

  private func shouldCallCompletionHandler() -> Bool {
    NSClassFromString("FLTFirebaseMessagingPlugin") == nil
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
    if isDitoChannel(userInfo) {
      let token = cachedFcmToken()
      handleDitoIfNeeded(userInfo: userInfo, fcmToken: token ?? "")
      if token == nil {
        fetchFcmTokenIfNeeded()
      }
    }
    if shouldCallCompletionHandler() {
      completionHandler(.newData)
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    logPush(context: "Push received (foreground)", userInfo: userInfo)
    notifyFirebase(userInfo: userInfo)
    if isDitoChannel(userInfo) {
      let token = cachedFcmToken()
      handleDitoIfNeeded(userInfo: userInfo, fcmToken: token ?? "")
      if token == nil {
        fetchFcmTokenIfNeeded()
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
    let userInfo = response.notification.request.content.userInfo
    logPush(context: "Push tap received", userInfo: userInfo)
    notifyFirebase(userInfo: userInfo)
    if isDitoChannel(userInfo) {
      Dito.notificationClick(userInfo: userInfo, callback: nil)
    }
    if let orig = originalDelegate, orig.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
      orig.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
    } else {
      completionHandler()
    }
  }
}
