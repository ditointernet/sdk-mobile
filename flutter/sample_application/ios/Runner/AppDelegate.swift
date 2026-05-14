import FirebaseMessaging
import Flutter
import UIKit
import UserNotifications
import dito_sdk

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  private var fcmToken: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    Messaging.messaging().delegate = self
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    Messaging.messaging().appDidReceiveMessage(userInfo)
    let handled = DitoSdkPlugin.didReceiveRemoteNotification(
      userInfo: userInfo,
      fcmToken: fcmToken
    )
    completionHandler(handled ? .newData : .noData)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    Messaging.messaging().appDidReceiveMessage(userInfo)
    _ = DitoSdkPlugin.didReceiveRemoteNotification(
      userInfo: userInfo,
      fcmToken: fcmToken
    )
    completionHandler([[.banner, .list, .sound, .badge]])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    Messaging.messaging().appDidReceiveMessage(userInfo)
    _ = DitoSdkPlugin.didReceiveNotificationClick(userInfo: userInfo)
    completionHandler()
  }

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    self.fcmToken = fcmToken
  }
}
