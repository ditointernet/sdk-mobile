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

  /// Lê `channel` no topo do payload e, se não achar, dentro do `data` aninhado.
  ///
  /// Dois problemas que estavam aqui e rejeitavam **todo** push da Dito, não só o rico:
  /// o channel-senders emite `"DITO"` em maiúsculas, e num push real a chave vive dentro
  /// de `data`, não no topo. O plugin Flutter já fazia as duas coisas certas.
  private static func ditoChannel(_ userInfo: [AnyHashable: Any]) -> String? {
    if let nested = userInfo["data"] as? [AnyHashable: Any],
       let channel = nested["channel"] as? String {
      return channel
    }
    return userInfo["channel"] as? String
  }

  private static func isDitoChannel(_ userInfo: [AnyHashable: Any]) -> Bool {
    ditoChannel(userInfo)?.caseInsensitiveCompare("DITO") == .orderedSame
  }

  private static func isDitoChannel(_ request: UNNotificationRequest) -> Bool {
    isDitoChannel(request.content.userInfo)
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
    guard isDitoChannel(userInfo) else {
      return false
    }
    Dito.notificationClick(userInfo: userInfo, callback: callback)
    return true
  }

  /// Mesmo que acima, levando `UNNotificationResponse.actionIdentifier` para o SDK saber
  /// qual botão foi tocado. O SDK descarta os identifiers de default/dismiss do sistema,
  /// então um toque no corpo continua sendo tratado como clique comum.
  @objc(didReceiveNotificationClickWithResponse:callback:)
  @discardableResult
  public static func didReceiveNotificationClick(
    response: UNNotificationResponse,
    callback: ((String) -> Void)? = nil
  ) -> Bool {
    guard isDitoChannel(response.notification.request.content.userInfo) else {
      return false
    }
    Dito.notificationClick(response: response, callback: callback)
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
}
