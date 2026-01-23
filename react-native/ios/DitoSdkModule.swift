import Foundation
import React
import DitoSDK
import UserNotifications

@objc(DitoSdkModule)
class DitoSdkModule: NSObject, RCTBridgeModule {

  static func moduleName() -> String! {
    return "DitoSdkModule"
  }

  static func requiresMainQueueSetup() -> Bool {
    return false
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
    guard isDitoChannel(request) else {
      return false
    }
    processNotificationRequest(request, fcmToken: fcmToken)
    return true
  }

  private static func isDitoChannel(_ request: UNNotificationRequest) -> Bool {
    let userInfo = request.content.userInfo
    let channel = userInfo["channel"] as? String
    return channel == "Dito"
  }

  private static func processNotificationRequest(_ request: UNNotificationRequest, fcmToken: String?) {
    guard let token = fcmToken else {
      return
    }
    let userInfo = request.content.userInfo
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
    guard let channel = userInfo["channel"] as? String, channel == "Dito" else {
      return false
    }
    Dito.notificationClick(userInfo: userInfo, callback: callback)
    return true
  }

  @objc
  func initialize(_ apiKey: String, apiSecret: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    if apiKey.isEmpty || apiSecret.isEmpty {
      reject(
        "INVALID_CREDENTIALS",
        "apiKey and apiSecret are required and cannot be empty",
        nil
      )
      return
    }

    Dito.shared.configure()
    resolve(nil)
  }

  @objc
  func identify(_ id: String, name: String?, email: String?, customData: [String: Any]?, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    if id.isEmpty {
      reject(
        "INVALID_PARAMETERS",
        "id is required and cannot be empty",
        nil
      )
      return
    }

    Dito.identify(
      id: id,
      name: name,
      email: email,
      customData: customData
    )
    resolve(nil)
  }

  @objc
  func track(_ action: String, data: [String: Any]?, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    if action.isEmpty {
      reject(
        "INVALID_PARAMETERS",
        "action is required and cannot be empty",
        nil
      )
      return
    }

    Dito.track(
      action: action,
      data: data
    )
    resolve(nil)
  }

  @objc
  func registerDeviceToken(_ token: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    if token.isEmpty {
      reject(
        "INVALID_PARAMETERS",
        "token is required and cannot be empty",
        nil
      )
      return
    }

    Dito.registerDevice(token: token)
    resolve(nil)
  }

  @objc
  func unregisterDeviceToken(_ token: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    if token.isEmpty {
      reject(
        "INVALID_PARAMETERS",
        "token is required and cannot be empty",
        nil
      )
      return
    }

    Dito.unregisterDevice(token: token)
    resolve(nil)
  }
}
