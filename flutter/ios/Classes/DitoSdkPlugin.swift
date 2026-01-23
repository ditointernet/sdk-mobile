import Flutter
import UIKit
import DitoSDK
import UserNotifications

public class DitoSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "br.com.dito/dito_sdk", binaryMessenger: registrar.messenger())
    let instance = DitoSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  /**
   * Handles a push notification request and processes it if it belongs to Dito channel.
   *
   * This method should be called from your UNUserNotificationCenterDelegate methods.
   * It verifies if the notification belongs to the Dito channel (channel == "Dito") and processes it accordingly.
   *
   * - Parameters:
   *   - request: The UNNotificationRequest received from the notification center
   *   - fcmToken: The FCM token for the device (optional, but recommended for notificationRead)
   * - Returns: true if the notification was processed by Dito SDK, false otherwise
   */
  @objc public static func didReceiveNotificationRequest(
    _ request: UNNotificationRequest,
    fcmToken: String?
  ) -> Bool {
    let userInfo = request.content.userInfo
    guard isDitoChannel(userInfo) else {
      return false
    }
    processNotificationRead(userInfo: userInfo, fcmToken: fcmToken)
    return true
  }

  private static func isDitoChannel(_ userInfo: [AnyHashable: Any]) -> Bool {
    let channel = userInfo["channel"] as? String
    return channel == "Dito"
  }

  private static func processNotificationRead(userInfo: [AnyHashable: Any], fcmToken: String?) {
    guard let token = fcmToken else { return }
    Dito.notificationRead(userInfo: userInfo, token: token)
  }

  /**
   * Handles a notification click/interaction and processes it if it belongs to Dito channel.
   *
   * This method should be called from your UNUserNotificationCenterDelegate's didReceive method.
   * It verifies if the notification belongs to the Dito channel and processes the click accordingly.
   *
   * - Parameters:
   *   - userInfo: The userInfo dictionary from the notification
   *   - callback: Optional callback executed with deeplink if available
   * - Returns: true if the notification was processed by Dito SDK, false otherwise
   */
  @objc public static func didReceiveNotificationClick(
    userInfo: [AnyHashable: Any],
    callback: ((String) -> Void)? = nil
  ) -> Bool {
    guard isDitoChannel(userInfo) else {
      return false
    }
    processNotificationClick(userInfo: userInfo, callback: callback)
    return true
  }

  private static func isDitoChannel(_ userInfo: [AnyHashable: Any]) -> Bool {
    let channel = userInfo["channel"] as? String
    return channel == "Dito"
  }

  private static func processNotificationClick(
    userInfo: [AnyHashable: Any],
    callback: ((String) -> Void)?
  ) {
    Dito.notificationClick(userInfo: userInfo, callback: callback)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "initialize":
      guard let args = call.arguments as? [String: Any],
            let apiKey = args["apiKey"] as? String,
            let apiSecret = args["apiSecret"] as? String else {
        result(FlutterError(
          code: "INVALID_CREDENTIALS",
          message: "apiKey and apiSecret are required and cannot be empty",
          details: nil
        ))
        return
      }

      if apiKey.isEmpty || apiSecret.isEmpty {
        result(FlutterError(
          code: "INVALID_CREDENTIALS",
          message: "apiKey and apiSecret are required and cannot be empty",
          details: nil
        ))
        return
      }

      Dito.shared.configure()
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
