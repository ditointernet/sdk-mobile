import DitoSDK
import FirebaseCore
import FirebaseMessaging
import Flutter
import UIKit
import UserNotifications

public class DitoSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "br.com.dito/dito_sdk", binaryMessenger: registrar.messenger())
    let instance = DitoSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    DitoNotificationDelegate.shared.configurePush(application: UIApplication.shared)
  }

  private static func channelFromUserInfo(_ userInfo: [AnyHashable: Any]) -> String? {
    if let data = userInfo["data"] as? [String: Any], let ch = data["channel"] as? String {
      return ch
    }
    return userInfo["channel"] as? String
  }

  private static func isDitoChannel(_ userInfo: [AnyHashable: Any]) -> Bool {
    channelFromUserInfo(userInfo) == "DITO"
  }

  private static func processNotificationReceived(userInfo: [AnyHashable: Any], fcmToken: String?) {
    guard let token = fcmToken else { return }
    Dito.notificationReceived(userInfo: userInfo, token: token)
  }

  @objc public static func didReceiveNotificationRequest(
    _ request: UNNotificationRequest,
    fcmToken: String?
  ) -> Bool {
    let userInfo = request.content.userInfo
    guard isDitoChannel(userInfo) else { return false }
    processNotificationReceived(userInfo: userInfo, fcmToken: fcmToken)
    return true
  }

  @objc public static func didReceiveRemoteNotification(
    userInfo: [AnyHashable: Any],
    fcmToken: String?
  ) -> Bool {
    guard isDitoChannel(userInfo) else { return false }
    processNotificationReceived(userInfo: userInfo, fcmToken: fcmToken)
    return true
  }

  @objc public static func didReceiveNotificationClick(
    userInfo: [AnyHashable: Any],
    callback: ((String) -> Void)? = nil
  ) -> Bool {
    guard isDitoChannel(userInfo) else { return false }
    Dito.notificationClick(userInfo: userInfo, callback: callback)
    return true
  }

  public func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) -> Bool {
    DitoNotificationDelegate.shared.application(
      application,
      didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: completionHandler
    )
    return false
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "setDebugMode":
      guard let args = call.arguments as? [String: Any],
            let enabled = args["enabled"] as? Bool else {
        result(FlutterError(
          code: "INVALID_PARAMETERS",
          message: "enabled is required and cannot be null",
          details: nil
        ))
        return
      }
      Dito.enableDebugMode(enabled)
      result(nil)
    case "initialize":
      guard let args = call.arguments as? [String: Any],
            let appKey = args["appKey"] as? String,
            let appSecret = args["appSecret"] as? String else {
        result(FlutterError(
          code: "INVALID_CREDENTIALS",
          message: "appKey and appSecret are required and cannot be empty",
          details: nil
        ))
        return
      }

      if appKey.isEmpty || appSecret.isEmpty {
        result(FlutterError(
          code: "INVALID_CREDENTIALS",
          message: "appKey and appSecret are required and cannot be empty",
          details: nil
        ))
        return
      }

      Dito.configure(appKey: appKey, appSecret: appSecret)
      result(nil)
    case "identify":
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String else {
        result(FlutterError(
          code: "INVALID_PARAMETERS",
          message: "id is required and cannot be empty",
          details: nil
        ))
        return
      }

      if id.isEmpty {
        result(FlutterError(
          code: "INVALID_PARAMETERS",
          message: "id is required and cannot be empty",
          details: nil
        ))
        return
      }

      let name = args["name"] as? String
      let email = args["email"] as? String
      let customData = args["customData"] as? [String: Any]

      Dito.identify(
        id: id,
        name: name,
        email: email,
        customData: customData
      )
      result(nil)
    case "track":
      guard let args = call.arguments as? [String: Any],
            let action = args["action"] as? String else {
        result(FlutterError(
          code: "INVALID_PARAMETERS",
          message: "action is required and cannot be empty",
          details: nil
        ))
        return
      }

      if action.isEmpty {
        result(FlutterError(
          code: "INVALID_PARAMETERS",
          message: "action is required and cannot be empty",
          details: nil
        ))
        return
      }

      let data = args["data"] as? [String: Any]

      Dito.track(
        action: action,
        data: data
      )
      result(nil)
    case "registerDeviceToken":
      guard let args = call.arguments as? [String: Any],
            let token = args["token"] as? String else {
        result(FlutterError(
          code: "INVALID_PARAMETERS",
          message: "token is required and cannot be empty",
          details: nil
        ))
        return
      }

      if token.isEmpty {
        result(FlutterError(
          code: "INVALID_PARAMETERS",
          message: "token is required and cannot be empty",
          details: nil
        ))
        return
      }

      Dito.registerDevice(token: token)
      result(nil)
    case "unregisterDeviceToken":
      guard let args = call.arguments as? [String: Any],
            let token = args["token"] as? String else {
        result(FlutterError(
          code: "INVALID_PARAMETERS",
          message: "token is required and cannot be empty",
          details: nil
        ))
        return
      }

      if token.isEmpty {
        result(FlutterError(
          code: "INVALID_PARAMETERS",
          message: "token is required and cannot be empty",
          details: nil
        ))
        return
      }

      Dito.unregisterDevice(token: token)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
