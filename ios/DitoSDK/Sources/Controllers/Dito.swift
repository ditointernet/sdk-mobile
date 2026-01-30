import Foundation

public class Dito {
  public static let shared = Dito()
  static var appKey: String = ""
  static var appSecret: String = ""
  static var signature: String = ""
  private var reachability = try! Reachability()
  private lazy var retry = DitoRetry()

  public static func enableDebugMode(_ enabled: Bool = true) {
    DitoLogger.isDebugEnabled = enabled
  }

  init() {
    Dito.appKey = Bundle.main.appKey
    let data = Bundle.main.appSecret.data(using: .utf8) ?? Data()
    Dito.appSecret = data.base64EncodedString()
    Dito.signature = Bundle.main.appSecret.sha1
  }

  public func configure() {
    DispatchQueue.main.async {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(self.reachabilityChanged(_:)),
        name: .reachabilityChanged,
        object: nil
      )

      do {
        try self.reachability.startNotifier()
      } catch let error {
        DitoLogger.error(error.localizedDescription)
      }
    }
  }

  nonisolated public static func sha1(for email: String) -> String {
    return email.sha1
  }

  /// Identifies a user in Dito CRM with individual parameters
  /// - Parameters:
  ///   - id: Unique user identifier
  ///   - name: User's name (optional)
  ///   - email: User's email (optional)
  ///   - customData: Additional custom data as dictionary (optional)
  nonisolated public static func identify(
    id: String,
    name: String? = nil,
    email: String? = nil,
    customData: [String: Any]? = nil
  ) {
    let user = createUser(name: name, email: email, customData: customData)
    DispatchQueue.main.async {
      let identifyController = DitoIdentify()
      identifyController.identify(id: id, data: user)
    }
  }

  private static func createUser(
    name: String?,
    email: String?,
    customData: [String: Any]?
  ) -> DitoUser {
    DitoUser(
      name: name,
      email: email,
      customData: customData
    )
  }

  /// Identifies a user in Dito CRM with DitoUser object
  /// - Parameters:
  ///   - id: Unique user identifier
  ///   - data: DitoUser object with user data
  /// - Warning: This method is deprecated. Use `identify(id:name:email:customData:)` instead.
  @available(*, deprecated, message: "Use identify(id:name:email:customData:) instead for consistency with Android SDK")
  nonisolated public static func identify(id: String, data: DitoUser) {
    DispatchQueue.main.async {
      let dtIdentify = DitoIdentify()
      dtIdentify.identify(id: id, data: data)
    }
  }

  /// Tracks an event in Dito CRM with individual parameters
  /// - Parameters:
  ///   - action: Event action name
  ///   - data: Additional event data as dictionary (optional)
  nonisolated public static func track(
    action: String,
    data: [String: Any]? = nil
  ) {
    let event = createEvent(action: action, customData: data)
    DispatchQueue.main.async {
      let trackController = DitoTrack()
      trackController.track(data: event)
    }
  }

  private static func createEvent(
    action: String,
    customData: [String: Any]?
  ) -> DitoEvent {
    DitoEvent(
      action: action,
      customData: customData
    )
  }

  /// Tracks an event in Dito CRM with DitoEvent object
  /// - Parameter event: DitoEvent object with event data
  /// - Warning: This method is deprecated. Use `track(action:data:)` instead.
  @available(*, deprecated, message: "Use track(action:data:) instead for consistency with Android SDK")
  nonisolated public static func track(event: DitoEvent) {
    DispatchQueue.main.async {
      let trackController = DitoTrack()
      trackController.track(data: event)
    }
  }

  /// Registers a Firebase Cloud Messaging (FCM) token for push notifications
  /// - Parameter token: The FCM token obtained from Firebase Messaging
  nonisolated public static func registerDevice(token: String) {
    DispatchQueue.main.async {
      let notificationController = DitoNotification()
      notificationController.registerToken(token: token)
    }
  }

  /// Unregisters a Firebase Cloud Messaging (FCM) token
  /// - Parameter token: The FCM token to unregister
  nonisolated public static func unregisterDevice(token: String) {
    DispatchQueue.main.async {
      let notificationController = DitoNotification()
      notificationController.unregisterToken(token: token)
    }
  }

  /// Called when a notification arrives (before click)
  /// - Parameters:
  ///   - userInfo: The notification data dictionary
  ///   - token: FCM token for the device
  nonisolated public static func notificationReceived(
    userInfo: [AnyHashable: Any],
    token: String
  ) {
    let notificationReceived = createNotificationReceived(from: userInfo)
    DispatchQueue.main.async {
      identifyUserForNotification(notificationReceived)
      trackNotificationReceived(notificationReceived, token: token)
    }
  }

  /// Called when a notification arrives (before click)
  /// - Parameters:
  ///   - userInfo: The notification data dictionary
  ///   - token: FCM token for the device
  /// - Warning: This method is deprecated. Use `notificationReceived(userInfo:token:)` instead.
  @available(*, deprecated, message: "Use notificationReceived(userInfo:token:) instead for consistency")
  nonisolated public static func notificationReceived(
    with userInfo: [AnyHashable: Any],
    token: String
  ) {
    let notificationReceived = createNotificationReceived(from: userInfo)
    DispatchQueue.main.async {
      identifyUserForNotification(notificationReceived)
      trackNotificationReceived(notificationReceived, token: token)
    }
  }

  /// Called when a notification arrives (before click) - DEPRECATED
  /// - Parameters:
  ///   - userInfo: The notification data dictionary
  ///   - token: FCM token for the device
  /// - Warning: This method is deprecated. Use `notificationReceived(userInfo:token:)` instead.
  @available(*, deprecated, message: "Use notificationReceived(userInfo:token:) instead. The name 'notificationRead' is inconsistent with Android's 'notificationReceived'.")
  nonisolated public static func notificationRead(
    userInfo: [AnyHashable: Any],
    token: String
  ) {
    notificationReceived(userInfo: userInfo, token: token)
  }

  /// Called when a notification arrives (before click) - DEPRECATED
  /// - Parameters:
  ///   - userInfo: The notification data dictionary
  ///   - token: FCM token for the device
  /// - Warning: This method is deprecated. Use `notificationReceived(userInfo:token:)` instead.
  @available(*, deprecated, message: "Use notificationReceived(userInfo:token:) instead. The name 'notificationRead' is inconsistent with Android's 'notificationReceived'.")
  nonisolated public static func notificationRead(
    with userInfo: [AnyHashable: Any],
    token: String
  ) {
    notificationReceived(with: userInfo, token: token)
  }

  private static func createNotificationReceived(from userInfo: [AnyHashable: Any]) -> DitoNotificationReceived {
    DitoNotificationReceived(with: userInfo)
  }

  private static func identifyUserForNotification(_ notificationReceived: DitoNotificationReceived) {
    let identifyController = DitoIdentify()
    identifyController.identify(
      id: notificationReceived.userId,
      data: DitoUser()
    )
  }

  private static func trackNotificationReceived(_ notificationReceived: DitoNotificationReceived, token: String) {
    let trackController = DitoTrack()
    let event = createNotificationTrackEvent(notificationReceived, token: token)
    trackController.track(data: event)
  }

  private static func createNotificationTrackEvent(_ notificationReceived: DitoNotificationReceived, token: String) -> DitoEvent {
    DitoEvent(
      action: "receive-ios-notification",
      customData: [
        "canal": "mobile",
        "token": token,
        "id-disparo": notificationReceived.logId,
        "id-notificacao": notificationReceived.notification,
        "nome_notificacao": notificationReceived.notificationName,
        "provedor": "firebase",
        "sistema_operacional": "Apple iPhone",
      ]
    )
  }

  /// Called when a notification is clicked
  /// - Parameters:
  ///   - userInfo: The notification data dictionary
  ///   - callback: Optional callback with deeplink
  /// - Returns: DitoNotificationReceived object with notification data
  @discardableResult
  nonisolated public static func notificationClick(
    userInfo: [AnyHashable: Any],
    callback: ((String) -> Void)? = nil
  ) -> DitoNotificationReceived {
    let notificationReceived = DitoNotificationReceived(with: userInfo)
    DispatchQueue.main.async {
      let notificationController = DitoNotification()
      notificationController.notificationClick(
        notificationId: notificationReceived.notification,
        reference: notificationReceived.reference,
        identifier: notificationReceived.identifier
      )
    }
    callback?(notificationReceived.deeplink)
    return notificationReceived
  }

  /// Called when a notification is clicked
  /// - Parameters:
  ///   - userInfo: The notification data dictionary
  ///   - callback: Optional callback with deeplink
  /// - Returns: DitoNotificationReceived object with notification data
  /// - Warning: This method is deprecated. Use `notificationClick(userInfo:callback:)` instead.
  @available(*, deprecated, message: "Use notificationClick(userInfo:callback:) instead for consistency")
  @discardableResult
  nonisolated public static func notificationClick(
    with userInfo: [AnyHashable: Any],
    callback: ((String) -> Void)? = nil
  ) -> DitoNotificationReceived {
    let notificationReceived = DitoNotificationReceived(with: userInfo)
    DispatchQueue.main.async {
      let notificationController = DitoNotification()
      notificationController.notificationClick(
        notificationId: notificationReceived.notification,
        reference: notificationReceived.reference,
        identifier: notificationReceived.identifier
      )
    }
    callback?(notificationReceived.deeplink)
    return notificationReceived
  }
}

//MARK: - Network Connection
extension Dito {

  @objc func reachabilityChanged(_ note: Notification) {

    if self.reachability.connection != .unavailable {
      retry.loadOffline()
    }
  }
}
