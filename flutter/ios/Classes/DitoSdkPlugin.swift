import DitoSDK
import FirebaseCore
import FirebaseMessaging
import Flutter
import UIKit
import UserNotifications

public class DitoSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let notificationEventsChannelName = "br.com.dito/notification_events"
  private static let notificationClickEventType = "notification_click"
  private static let clickDedupeWindow: TimeInterval = 1.5
  private static var notificationEventSink: FlutterEventSink?
  private static var lastClickAt: Date?
  private static var lastClickKey: String?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "br.com.dito/dito_sdk", binaryMessenger: registrar.messenger())
    let instance = DitoSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
    let eventsChannel = FlutterEventChannel(
      name: notificationEventsChannelName,
      binaryMessenger: registrar.messenger()
    )
    eventsChannel.setStreamHandler(instance)
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    DitoNotificationDelegate.shared.configurePush(application: UIApplication.shared)
  }

  private static func channelFromUserInfo(_ userInfo: [AnyHashable: Any]) -> String? {
    notificationData(from: userInfo)["channel"] as? String
  }

  private static func isDitoChannel(_ userInfo: [AnyHashable: Any]) -> Bool {
    channelFromUserInfo(userInfo)?.uppercased() == "DITO"
  }

  private static func notificationData(from userInfo: [AnyHashable: Any]) -> [AnyHashable: Any] {
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

  private static func normalizedNotificationData(_ userInfo: [AnyHashable: Any]) -> [AnyHashable: Any] {
    var normalized = userInfo
    if normalized["link"] == nil, let deeplink = normalized["deeplink"] as? String {
      normalized["link"] = deeplink
    }
    if normalized["deeplink"] == nil, let link = normalized["link"] as? String {
      normalized["deeplink"] = link
    }
    return normalized
  }

  private static func processNotificationReceived(userInfo: [AnyHashable: Any], fcmToken: String?) {
    let token = fcmToken ?? ""
    Dito.notificationReceived(userInfo: notificationData(from: userInfo), token: token)
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
    let source = notificationData(from: userInfo)
    guard isDitoChannel(source) else { return false }
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

  internal static func emitNotificationClickEvent(userInfo: [AnyHashable: Any], deeplink: String) {
    guard let sink = notificationEventSink else { return }
    let source = notificationData(from: userInfo)

    var payload: [String: Any] = [:]
    payload["type"] = notificationClickEventType
    payload["deeplink"] = deeplink
    payload["notificationId"] = source["notification"] as? String ?? ""
    payload["reference"] = source["reference"] as? String ?? ""
    payload["logId"] = source["log_id"] as? String ?? ""
    payload["notificationName"] = source["notification_name"] as? String ?? ""
    payload["userId"] = source["user_id"] as? String ?? ""

    DispatchQueue.main.async {
      sink(payload)
    }
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
    case "initializeWithApiKey":
      guard let args = call.arguments as? [String: Any],
            let apiKey = args["apiKey"] as? String,
            let bundleId = args["bundleId"] as? String,
            !apiKey.isEmpty, !bundleId.isEmpty else {
        result(FlutterError(
          code: "INVALID_CREDENTIALS",
          message: "apiKey and bundleId are required and cannot be empty",
          details: nil
        ))
        return
      }
      Dito.configure(apiKey: apiKey, bundleId: bundleId)
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
      ) { operation in
        self.completeOperationResult(operation, result: result, errorCode: "NETWORK_ERROR")
      }
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
      ) { operation in
        self.completeOperationResult(operation, result: result, errorCode: "NETWORK_ERROR")
      }
    case "logout":
      Dito.logout()
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

      Dito.registerDevice(token: token) { operation in
        self.completeOperationResult(operation, result: result, errorCode: "NETWORK_ERROR")
      }
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

      Dito.unregisterDevice(token: token) { operation in
        self.completeOperationResult(operation, result: result, errorCode: "NETWORK_ERROR")
      }
    case "handleNotificationClick":
      guard let args = call.arguments as? [String: Any] else {
        result(false)
        return
      }
      var userInfo: [AnyHashable: Any] = [:]
      for (k, v) in args {
        userInfo[k] = v
      }
      let handled = DitoSdkPlugin.didReceiveNotificationClick(userInfo: userInfo)
      result(handled)
    case "setNotificationOptions":
      let args = call.arguments as? [String: Any] ?? [:]
      let soundResourceName = args["soundResourceName"] as? String
      let options = DitoNotificationOptions(soundName: soundResourceName)
      Dito.setNotificationOptions(options)
      result(nil)
    case "getNotifications":
      let notifications = Dito.shared.getNotifications()
      let maps: [[String: Any]] = notifications.map { info in
        [
          "id": info.id,
          "notificationId": info.notificationId,
          "reference": info.reference,
          "title": info.title,
          "message": info.message,
          "link": info.link,
          "receivedAt": Int64(info.receivedAt.timeIntervalSince1970 * 1000),
          "isRead": info.isRead
        ]
      }
      result(maps)
    case "markNotificationAsRead":
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String else {
        result(FlutterError(code: "INBOX_ERROR", message: "id argument missing", details: nil))
        return
      }
      Dito.shared.markNotificationAsRead(id: id)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    DitoSdkPlugin.notificationEventSink = events
    return nil
  }

  private func completeOperationResult(
    _ operation: Result<DitoOperationStatus, Error>,
    result: @escaping FlutterResult,
    errorCode: String
  ) {
    DispatchQueue.main.async {
      switch operation {
      case .success(let status):
        result(["status": self.rawOperationStatus(status)])
      case .failure(let error):
        result(FlutterError(
          code: errorCode,
          message: error.localizedDescription,
          details: nil
        ))
      }
    }
  }

  private func rawOperationStatus(_ status: DitoOperationStatus) -> String {
    switch status {
    case .sent:
      return "sent"
    case .savedLocally:
      return "saved_locally"
    }
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    DitoSdkPlugin.notificationEventSink = nil
    return nil
  }
}
