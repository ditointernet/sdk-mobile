import DitoSDK
import FirebaseCore
import FirebaseMessaging
import Flutter
import UIKit
import UserNotifications

public class DitoSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let notificationEventsChannelName = "br.com.dito/notification_events"
  private static let notificationClickEventType = "notification_click"
  private static var notificationEventSink: FlutterEventSink?

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
    DitoNotificationDelegate.ensureDitoConfigured()
    DitoNotificationDelegate.shared.configurePush(application: UIApplication.shared)
  }

  private static func isDitoChannel(_ userInfo: [AnyHashable: Any]) -> Bool {
    DitoNotificationDelegate.isDitoChannel(userInfo)
  }

  private static func resolvedFcmToken(_ fcmToken: String?) -> String {
    if let token = fcmToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
      return token
    }
    return UserDefaults.standard.string(forKey: "FCMToken") ?? ""
  }

  private static func processNotificationReceived(userInfo: [AnyHashable: Any], fcmToken: String?) {
    DitoNotificationDelegate.ensureDitoConfigured()
    let normalized = DitoNotificationDelegate.normalizedDitoUserInfo(userInfo)
    Dito.notificationReceived(userInfo: normalized, token: resolvedFcmToken(fcmToken))
  }

  @objc public static func didReceiveNotificationRequest(
    _ request: UNNotificationRequest,
    fcmToken: String?
  ) -> Bool {
    let normalized = DitoNotificationDelegate.normalizedDitoUserInfo(request.content.userInfo)
    guard isDitoChannel(normalized) else { return false }
    processNotificationReceived(userInfo: request.content.userInfo, fcmToken: fcmToken)
    return true
  }

  @objc public static func didReceiveRemoteNotification(
    userInfo: [AnyHashable: Any],
    fcmToken: String?
  ) -> Bool {
    let normalized = DitoNotificationDelegate.normalizedDitoUserInfo(userInfo)
    guard isDitoChannel(normalized) else { return false }
    processNotificationReceived(userInfo: userInfo, fcmToken: fcmToken)
    return true
  }

  @objc public static func didReceiveNotificationClick(
    userInfo: [AnyHashable: Any],
    callback: ((String) -> Void)? = nil
  ) -> Bool {
    didReceiveNotificationClick(userInfo: userInfo, actionIdentifier: nil, callback: callback)
  }

  /// Same as above, but carries `UNNotificationResponse.actionIdentifier` so a tap on
  /// an action button reports which button was tapped.
  ///
  /// Kept as a separate entry point rather than a defaulted parameter on the one
  /// above, so the existing Objective-C selector stays untouched for host apps that
  /// already call it from an AppDelegate.
  @objc(didReceiveNotificationClickWithUserInfo:actionIdentifier:callback:)
  @discardableResult
  public static func didReceiveNotificationClick(
    userInfo: [AnyHashable: Any],
    actionIdentifier: String?,
    callback: ((String) -> Void)? = nil
  ) -> Bool {
    let normalized = DitoNotificationDelegate.normalizedDitoUserInfo(userInfo)
    guard isDitoChannel(normalized) else { return false }
    let received = Dito.notificationClick(
      userInfo: normalized,
      actionIdentifier: actionIdentifier,
      callback: callback
    )
    emitNotificationClickEvent(userInfo: normalized, received: received)
    return true
  }

  /// Emits the click on the Dart stream.
  ///
  /// The deeplink comes from `received.resolvedLink`, which is the button's own
  /// already-iOS-resolved link for an action tap and the notification's deeplink
  /// for a tap on the body. Everything else still comes from the raw payload:
  /// `DitoNotificationReceived` exposes the rich-push fields publicly but keeps
  /// `notification`, `reference`, `logId`, `notificationName` and `userId` internal,
  /// so they are not readable from this module.
  internal static func emitNotificationClickEvent(
    userInfo: [AnyHashable: Any],
    received: DitoNotificationReceived
  ) {
    guard let sink = notificationEventSink else { return }
    let normalized = DitoNotificationDelegate.normalizedDitoUserInfo(userInfo)
    let source = DitoNotificationDelegate.nestedPayload(normalized[AnyHashable("data")] ?? normalized["data"]) ?? normalized

    var payload: [String: Any] = [:]
    payload["type"] = notificationClickEventType
    payload["deeplink"] = received.resolvedLink
    payload["notificationId"] = source["notification"] as? String ?? ""
    // Sempre vazio: `reference` está em retirada e a atribuição ancora em
    // `user_id`. A chave permanece para não quebrar quem já lê este evento.
    payload["reference"] = ""
    payload["logId"] = source["log_id"] as? String ?? ""
    payload["notificationName"] = source["notification_name"] as? String ?? ""
    payload["userId"] = source["user_id"] as? String ?? ""
    payload["actionId"] = received.actionId
    payload["actionLabel"] = received.actionLabel
    payload["customData"] = received.customData

    DispatchQueue.main.async {
      sink(payload)
    }
  }

  public func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    Messaging.messaging().token { token, _ in
      guard let token, !token.isEmpty else { return }
      UserDefaults.standard.set(token, forKey: "FCMToken")
    }
  }

  public func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) -> Bool {
    let normalized = DitoNotificationDelegate.normalizedDitoUserInfo(userInfo)
    let isDito = DitoSdkPlugin.isDitoChannel(normalized)
    DitoNotificationDelegate.shared.application(
      application,
      didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: completionHandler
    )
    return isDito
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
    case "handleNotificationReceived":
      guard let args = call.arguments as? [String: Any] else {
        result(false)
        return
      }
      var userInfo: [AnyHashable: Any] = [:]
      for (key, value) in args where key != "token" {
        userInfo[key] = value
      }
      let token = args["token"] as? String
      let handled = DitoSdkPlugin.didReceiveRemoteNotification(userInfo: userInfo, fcmToken: token)
      result(handled)
    case "handleNotificationClick":
      guard let args = call.arguments as? [String: Any] else {
        result(false)
        return
      }
      var userInfo: [AnyHashable: Any] = [:]
      for (k, v) in args {
        userInfo[k] = v
      }
      // A emissão no stream Dart acontece dentro de didReceiveNotificationClick.
      let handled = DitoSdkPlugin.didReceiveNotificationClick(
        userInfo: userInfo,
        actionIdentifier: args["actionIdentifier"] as? String
      )
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
          // Sempre vazio: `reference` foi retirado do payload e a atribuição
          // ancora em `user_id`. A chave fica no mapa para não quebrar quem
          // já lê este evento em Dart.
          "reference": "",
          "title": info.title,
          "message": info.message,
          "link": info.link,
          "receivedAt": Int64(info.receivedAt.timeIntervalSince1970 * 1000),
          "isRead": info.isRead,
          "image": info.image,
          "customData": info.customData
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

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    DitoSdkPlugin.notificationEventSink = nil
    return nil
  }
}
