import Foundation
import UIKit

public enum DitoOperationStatus {
  case sent
  case savedLocally
}

enum DitoOperationError: LocalizedError {
  case invalidIdentifier

  var errorDescription: String? {
    switch self {
    case .invalidIdentifier:
      return "id is required and cannot be empty"
    }
  }
}

public class Dito {
  public static let shared = Dito()
  static var appKey: String = ""
  static var appSecret: String = ""
  static var signature: String = ""
  static var apiKey: String = ""
  static var bundleId: String = ""
  private static var notificationOptions = DitoNotificationOptions()
  public static var notificationReceivedListener: (([AnyHashable: Any]) -> Void)? = nil
  #if DEBUG
  static var testURLSessionConfiguration: URLSessionConfiguration? = nil
  static var testNotificationReceivedIngestClient: MobileIngestClientProtocol?
  static var testIdentifyTrackIngestClient: MobileIngestClientProtocol?
  #endif
  private var reachability = try! Reachability()
  private var backingRetry: DitoRetry?
  var retry: DitoRetry {
    if let existing = backingRetry {
      return existing
    }
    #if DEBUG
    let created = DitoRetry(client: Dito.testIdentifyTrackIngestClient)
    #else
    let created = DitoRetry()
    #endif
    backingRetry = created
    return created
  }

  public static func enableDebugMode(_ enabled: Bool = true) {
    DitoLogger.isDebugEnabled = enabled
  }

  public static func setNotificationOptions(_ options: DitoNotificationOptions) {
    Dito.notificationOptions = options
  }

  init() {
    if Dito.appKey.isEmpty && Dito.appSecret.isEmpty && Dito.signature.isEmpty && Dito.apiKey.isEmpty {
      let rawKey = Bundle.main.appKey
      let rawSecret = Bundle.main.appSecret
      guard !rawKey.isEmpty else { return }
      if rawSecret.isEmpty {
        Dito.apiKey = rawKey
        Dito.bundleId = Bundle.main.bundleIdentifier ?? ""
      } else {
        Dito.appKey = rawKey
        let data = rawSecret.data(using: .utf8) ?? Data()
        Dito.appSecret = data.base64EncodedString()
        Dito.signature = rawSecret.sha1
      }
    }
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

  public static func configure(appKey: String, appSecret: String) {
    let shared = Dito.shared
    Dito.appKey = appKey
    let data = appSecret.data(using: .utf8) ?? Data()
    Dito.appSecret = data.base64EncodedString()
    Dito.signature = appSecret.sha1
    shared.configure()
  }

  public static func configure(apiKey: String, bundleId: String) {
    let shared = Dito.shared
    Dito.apiKey = apiKey
    Dito.bundleId = bundleId
    shared.configure()
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
    customData: [String: Any]? = nil,
    completion: ((Result<DitoOperationStatus, Error>) -> Void)? = nil
  ) {
    let user = createUser(name: name, email: email, customData: customData)
    DispatchQueue.main.async {
      #if DEBUG
      let identifyController = DitoIdentify(retry: Dito.shared.retry, client: Dito.testIdentifyTrackIngestClient)
      #else
      let identifyController = DitoIdentify(retry: Dito.shared.retry)
      #endif
      identifyController.identify(id: id, data: user, completion: completion)
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
  nonisolated public static func identify(
    id: String,
    data: DitoUser,
    completion: ((Result<DitoOperationStatus, Error>) -> Void)? = nil
  ) {
    DispatchQueue.main.async {
      #if DEBUG
      let dtIdentify = DitoIdentify(retry: Dito.shared.retry, client: Dito.testIdentifyTrackIngestClient)
      #else
      let dtIdentify = DitoIdentify(retry: Dito.shared.retry)
      #endif
      dtIdentify.identify(id: id, data: data, completion: completion)
    }
  }

  nonisolated public static func logout() {
    DitoIdentifyOffline.shared.logout()
  }

  /// Tracks an event in Dito CRM with individual parameters
  /// - Parameters:
  ///   - action: Event action name
  ///   - data: Additional event data as dictionary (optional)
  nonisolated public static func track(
    action: String,
    data: [String: Any]? = nil,
    completion: ((Result<DitoOperationStatus, Error>) -> Void)? = nil
  ) {
    let event = createEvent(action: action, customData: data)
    DispatchQueue.main.async {
      #if DEBUG
      let trackController = DitoTrack(client: Dito.testIdentifyTrackIngestClient)
      #else
      let trackController = DitoTrack()
      #endif
      trackController.track(data: event, completion: completion)
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
  nonisolated public static func track(
    event: DitoEvent,
    completion: ((Result<DitoOperationStatus, Error>) -> Void)? = nil
  ) {
    DispatchQueue.main.async {
      #if DEBUG
      let trackController = DitoTrack(client: Dito.testIdentifyTrackIngestClient)
      #else
      let trackController = DitoTrack()
      #endif
      trackController.track(data: event, completion: completion)
    }
  }

  /// Registers a Firebase Cloud Messaging (FCM) token for push notifications
  /// - Parameter token: The FCM token obtained from Firebase Messaging
  nonisolated public static func registerDevice(
    token: String,
    completion: ((Result<DitoOperationStatus, Error>) -> Void)? = nil
  ) {
    DispatchQueue.main.async {
      let notificationController = DitoNotification()
      notificationController.options = Dito.notificationOptions
      notificationController.registerToken(token: token, completion: completion)
    }
  }

  /// Unregisters a Firebase Cloud Messaging (FCM) token
  /// - Parameter token: The FCM token to unregister
  nonisolated public static func unregisterDevice(
    token: String,
    completion: ((Result<DitoOperationStatus, Error>) -> Void)? = nil
  ) {
    DispatchQueue.main.async {
      let notificationController = DitoNotification()
      notificationController.options = Dito.notificationOptions
      notificationController.unregisterToken(token: token, completion: completion)
    }
  }

  /// Called when a notification arrives (before click)
  /// - Parameters:
  ///   - userInfo: The notification data dictionary
  ///   - token: FCM token for the device
  nonisolated public static func notificationReceived(
    userInfo: [AnyHashable: Any],
    token: String,
    completion: ((Result<Void, Error>) -> Void)? = nil
  ) {
    let received = createNotificationReceived(from: userInfo)
    sendNotificationReceivedActivities(received, token: token, completion: completion)
    Dito.notificationReceivedListener?(userInfo)
  }

  /// Called when a notification arrives (before click)
  /// - Parameters:
  ///   - userInfo: The notification data dictionary
  ///   - token: FCM token for the device
  /// - Warning: This method is deprecated. Use `notificationReceived(userInfo:token:)` instead.
  @available(*, deprecated, message: "Use notificationReceived(userInfo:token:) instead for consistency")
  nonisolated public static func notificationReceived(
    with userInfo: [AnyHashable: Any],
    token: String,
    completion: ((Result<Void, Error>) -> Void)? = nil
  ) {
    notificationReceived(userInfo: userInfo, token: token, completion: completion)
  }

  /// Called when a notification arrives (before click) - DEPRECATED
  /// - Parameters:
  ///   - userInfo: The notification data dictionary
  ///   - token: FCM token for the device
  /// - Warning: This method is deprecated. Use `notificationReceived(userInfo:token:)` instead.
  @available(*, deprecated, message: "Use notificationReceived(userInfo:token:) instead. The name 'notificationRead' is inconsistent with Android's 'notificationReceived'.")
  nonisolated public static func notificationRead(
    userInfo: [AnyHashable: Any],
    token: String,
    completion: ((Result<Void, Error>) -> Void)? = nil
  ) {
    notificationReceived(userInfo: userInfo, token: token, completion: completion)
  }

  /// Called when a notification arrives (before click) - DEPRECATED
  /// - Parameters:
  ///   - userInfo: The notification data dictionary
  ///   - token: FCM token for the device
  /// - Warning: This method is deprecated. Use `notificationReceived(userInfo:token:)` instead.
  @available(*, deprecated, message: "Use notificationReceived(userInfo:token:) instead. The name 'notificationRead' is inconsistent with Android's 'notificationReceived'.")
  nonisolated public static func notificationRead(
    with userInfo: [AnyHashable: Any],
    token: String,
    completion: ((Result<Void, Error>) -> Void)? = nil
  ) {
    notificationReceived(userInfo: userInfo, token: token, completion: completion)
  }

  private static func createNotificationReceived(from userInfo: [AnyHashable: Any]) -> DitoNotificationReceived {
    DitoNotificationReceived(with: userInfo)
  }

  public static func shouldDeliverReceiveNotification(
    notification: String,
    logId: String
  ) -> Bool {
    !DitoNotificationReceiveTracker.wasDelivered(notification: notification, logId: logId)
  }

  private static func sendNotificationReceivedActivities(
    _ received: DitoNotificationReceived,
    token: String,
    completion: ((Result<Void, Error>) -> Void)? = nil
  ) {
    Dito.shared.configure()
    _ = DitoCoreDataManager.shared.persistentContainer
    DitoNotificationCoreDataManager.shared.insert(
      notificationId: received.notification,
      reference: received.reference,
      title: received.title,
      message: received.message,
      link: received.deeplink
    )

    guard !received.userId.isEmpty else {
      DitoLogger.warning(
        "receive-ios-notification não enviado: user_id ausente no payload (topo ou data)"
      )
      completion?(.success(()))
      return
    }

    if !shouldDeliverReceiveNotification(
      notification: received.notification,
      logId: received.logId
    ) {
      #if DEBUG
      DitoLogger.debug("receive-ios-notification já entregue para notification=\(received.notification)")
      #endif
      completion?(.success(()))
      return
    }

    Task {
      await deliverNotificationReceivedActivities(
        received: received,
        token: token,
        completion: completion
      )
    }
  }

  private static func deliverNotificationReceivedActivities(
    received: DitoNotificationReceived,
    token: String,
    completion: ((Result<Void, Error>) -> Void)? = nil
  ) async {
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    let isRunningUnitTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    if !isRunningUnitTests {
      await MainActor.run {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "DitoReceiveNotification") {
          if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
          }
        }
      }
    }

    defer {
      if backgroundTask != .invalid {
        Task { @MainActor in
          UIApplication.shared.endBackgroundTask(backgroundTask)
        }
      }
    }

    let mapper = ActivityMapper()
    #if DEBUG
    let ingestClient: MobileIngestClientProtocol =
      Dito.testNotificationReceivedIngestClient ?? MobileIngestClient.buildFromDitoConfig()
    #else
    let ingestClient: MobileIngestClientProtocol = MobileIngestClient.buildFromDitoConfig()
    #endif
    let identifyActivity = mapper.mapFromDitoUser(userData: DitoUser(), userId: received.userId)
    let trackActivity = mapper.mapFromDitoEvent(createNotificationTrackEvent(received, token: token))
    let request = mapper.buildRequest(
      userId: received.userId,
      activities: [identifyActivity, trackActivity]
    )

    do {
      try await ingestClient.activity(request)
      DitoNotificationReceiveTracker.markDelivered(
        notification: received.notification,
        logId: received.logId
      )
      DitoLogger.information("✅ [NOTIFICATION RECEIVED] receive-ios-notification enviado")
      completion?(.success(()))
    } catch {
      DitoLogger.error(error.localizedDescription)
      let pending = DitoNotificationReceivePending(
        userId: received.userId,
        token: token,
        notification: received.notification,
        reference: received.reference,
        logId: received.logId,
        notificationName: received.notificationName
      )
      DitoNotificationOffline().notificationReceive(pending)
      if !isRunningUnitTests {
        Dito.shared.retry.loadOffline()
      }
      completion?(.success(()))
    }
  }

  public func getNotifications() -> [DitoNotificationInfo] {
    DitoNotificationCoreDataManager.shared.getAll().map { record in
      DitoNotificationInfo(
        id: record.id ?? "",
        notificationId: record.notificationId ?? "",
        reference: record.reference ?? "",
        title: record.title ?? "",
        message: record.message ?? "",
        link: record.link ?? "",
        receivedAt: record.receivedAt ?? Date(),
        isRead: record.isRead
      )
    }
  }

  public func markNotificationAsRead(id: String) {
    DitoNotificationCoreDataManager.shared.markAsRead(id: id)
  }

  static func createNotificationTrackEvent(_ notificationReceived: DitoNotificationReceived, token: String) -> DitoEvent {
    DitoEvent(
      action: "receive-ios-notification",
      customData: [
        "token": token,
        "dispatch_id": notificationReceived.logId,
        "notification_id": notificationReceived.notification,
        "notification_name": notificationReceived.notificationName,
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
      notificationController.options = Dito.notificationOptions
      notificationController.notificationClick(
        notificationId: notificationReceived.notification,
        reference: notificationReceived.reference,
        identifier: notificationReceived.identifier
      )
    }
    if !notificationReceived.notification.isEmpty {
      DitoNotificationCoreDataManager.shared.markAsReadByNotificationId(notificationReceived.notification)
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
      notificationController.options = Dito.notificationOptions
      notificationController.notificationClick(
        notificationId: notificationReceived.notification,
        reference: notificationReceived.reference,
        identifier: notificationReceived.identifier
      )
    }
    if !notificationReceived.notification.isEmpty {
      DitoNotificationCoreDataManager.shared.markAsReadByNotificationId(notificationReceived.notification)
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

#if DEBUG
extension Dito {
  static func awaitNotificationReceivedDelivery(
    userInfo: [AnyHashable: Any],
    token: String
  ) async {
    let received = createNotificationReceived(from: userInfo)
    _ = DitoCoreDataManager.shared.persistentContainer
    DitoNotificationCoreDataManager.shared.insert(
      notificationId: received.notification,
      reference: received.reference,
      title: received.title,
      message: received.message,
      link: received.deeplink
    )
    await deliverNotificationReceivedActivities(received: received, token: token)
  }

  static func invalidateRetryCacheForTests() {
    shared.backingRetry = nil
  }

  static func resetFacadeIsolationState() {
    NotificationCenter.default.removeObserver(shared, name: .reachabilityChanged, object: nil)
    shared.reachability.stopNotifier()
    shared.reachability.debug_connectionOverride = nil
    shared.backingRetry = nil
    appKey = ""
    appSecret = ""
    signature = ""
    apiKey = ""
    bundleId = ""
    testURLSessionConfiguration = nil
    testNotificationReceivedIngestClient = nil
    testIdentifyTrackIngestClient = nil
  }

  static func setReachabilityConnectionOverrideForTests(_ connection: Reachability.Connection?) {
    shared.reachability.debug_connectionOverride = connection
  }

  static func postReachabilityChangedNotificationForTests() {
    NotificationCenter.default.post(name: .reachabilityChanged, object: shared.reachability)
  }
}
#endif
