import DitoSDK
import Foundation
import React
import UserNotifications

@objc(DitoSdkModule)
class DitoSdkModule: RCTEventEmitter {
  private static let notificationClickEvent = "DitoNotificationClick"
  private static let clickDedupeWindow: TimeInterval = 1.5
  private static weak var eventEmitter: DitoSdkModule?
  private static var lastClickAt: Date?
  private static var lastClickKey: String?

  override init() {
    super.init()
    DitoSdkModule.eventEmitter = self
  }

  @objc override static func requiresMainQueueSetup() -> Bool {
    return false
  }

  override func supportedEvents() -> [String]! {
    return [DitoSdkModule.notificationClickEvent]
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

  private static func notificationSourceUserInfo(_ userInfo: [AnyHashable: Any]) -> [AnyHashable: Any] {
    if let data = userInfo["data"] as? [AnyHashable: Any] {
      return normalizedNotificationData(data)
    }
    if let data = userInfo["data"] as? [String: Any] {
      var bridgedData: [AnyHashable: Any] = [:]
      data.forEach { bridgedData[$0.key] = $0.value }
      return normalizedNotificationData(bridgedData)
    }
    if let rawData = userInfo["data"] as? String,
       let jsonData = rawData.data(using: .utf8),
       let data = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
      var bridgedData: [AnyHashable: Any] = [:]
      data.forEach { bridgedData[$0.key] = $0.value }
      return normalizedNotificationData(bridgedData)
    }
    return normalizedNotificationData(userInfo)
  }

  private static func isDitoChannel(_ userInfo: [AnyHashable: Any]) -> Bool {
    let channel = notificationSourceUserInfo(userInfo)["channel"] as? String
    return channel?.uppercased() == "DITO"
  }

  private static func normalizedNotificationData(_ userInfo: [AnyHashable: Any]) -> [AnyHashable: Any] {
    var normalized = userInfo
    if let channel = normalized["channel"] as? String {
      normalized["channel"] = channel.uppercased()
    }
    if normalized["link"] == nil, let deeplink = normalized["deeplink"] as? String {
      normalized["link"] = deeplink
    }
    if normalized["deeplink"] == nil, let link = normalized["link"] as? String {
      normalized["deeplink"] = link
    }
    return normalized
  }

  private static func processNotificationReceived(userInfo: [AnyHashable: Any], fcmToken: String?) {
    Dito.notificationReceived(userInfo: notificationSourceUserInfo(userInfo), token: fcmToken ?? "")
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
    let source = notificationSourceUserInfo(userInfo)
    guard isDitoChannel(source) else {
      return false
    }
    if isDuplicateClick(source) {
      return true
    }
    Dito.notificationClick(userInfo: source) { deeplink in
      callback?(deeplink)
      emitNotificationClickEvent(userInfo: source, deeplink: deeplink)
    }
    return true
  }

  private static func isDuplicateClick(_ userInfo: [AnyHashable: Any]) -> Bool {
    let key = [
      userInfo["notification"] as? String ?? "",
      userInfo["reference"] as? String ?? "",
      userInfo["log_id"] as? String ?? "",
      userInfo["deeplink"] as? String ?? userInfo["link"] as? String ?? ""
    ].joined(separator: "|")
    let now = Date()
    let duplicate = key == lastClickKey && lastClickAt.map { now.timeIntervalSince($0) < clickDedupeWindow } == true
    lastClickKey = key
    lastClickAt = now
    return duplicate
  }

  private static func emitNotificationClickEvent(userInfo: [AnyHashable: Any], deeplink: String) {
    let source = notificationSourceUserInfo(userInfo)
    let payload: [String: Any] = [
      "deeplink": deeplink,
      "notificationId": source["notification"] as? String ?? "",
      "reference": source["reference"] as? String ?? "",
      "logId": source["log_id"] as? String ?? "",
      "notificationName": source["notification_name"] as? String ?? "",
      "userId": source["user_id"] as? String ?? ""
    ]
    DispatchQueue.main.async {
      DitoSdkModule.eventEmitter?.sendEvent(
        withName: DitoSdkModule.notificationClickEvent,
        body: payload
      )
    }
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
  func logout(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    Dito.logout()
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
    let options = DitoNotificationOptions(soundName: soundResourceName)
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

  @objc
  func handleNotificationClick(_ userInfo: [String: Any], resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    var normalizedUserInfo: [AnyHashable: Any] = [:]
    for (key, value) in userInfo {
      normalizedUserInfo[key] = value
    }
    resolve(DitoSdkModule.didReceiveNotificationClick(userInfo: normalizedUserInfo))
  }
}
