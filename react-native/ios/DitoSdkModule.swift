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
   *   - fcmToken: The FCM token for the device (optional, but recommended for notificationReceived)
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
    Dito.notificationReceived(userInfo: userInfo, token: token)
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
  func initializeWithApiKey(
    _ apiKey: String,
    bundleId: String,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    if apiKey.isEmpty || bundleId.isEmpty {
      reject(
        "INVALID_CREDENTIALS",
        "apiKey and bundleId are required and cannot be empty",
        nil
      )
      return
    }

    Dito.configure(apiKey: apiKey, bundleId: bundleId)
    resolve(nil)
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

    Dito.configure(appKey: apiKey, appSecret: apiSecret)
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

  @objc
  func setNotificationOptions(_ optionsDict: [String: Any], resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    let soundResourceName = optionsDict["soundResourceName"] as? String
    let badgeEnabled = optionsDict["badgeEnabled"] as? Bool ?? true
    let options = DitoNotificationOptions(soundName: soundResourceName, badgeEnabled: badgeEnabled)
    Dito.setNotificationOptions(options)
    resolve(nil)
  }

  @objc
  func getNotifications(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    DispatchQueue.global(qos: .background).async {
      let records = Dito.shared.getNotifications()
      let array: [[String: Any]] = records.map { info in
        return [
          "id": info.id,
          "notificationId": info.notificationId,
          "reference": info.reference,
          "title": info.title,
          "message": info.message,
          "link": info.link,
          "receivedAt": info.receivedAt.timeIntervalSince1970 * 1000,
          "isRead": info.isRead
        ]
      }
      resolve(array)
    }
  }

  @objc
  func markNotificationAsRead(_ id: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    Dito.shared.markNotificationAsRead(id: id)
    resolve(nil)
  }
}
