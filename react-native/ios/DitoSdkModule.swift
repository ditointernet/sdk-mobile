import Foundation
import React
import DitoSDK
import UserNotifications

/// Estado compartilhado entre o caminho estático da bridge e a instância que o React cria.
///
/// `didReceiveNotificationClick` é chamado do `AppDelegate` do app host, não tem instância
/// em mãos e roda em thread qualquer; os métodos que o JavaScript chama rodam na fila do
/// módulo. Por isso o estado fica atrás de um lock, num objeto, em vez de em `static var`
/// soltas: `static var` mutável não compila em Swift 6 sem anotação de concorrência, e o
/// podspec deste pacote pede uma versão de Swift mais nova que a do plugin Flutter.
private final class DitoClickBridgeState: @unchecked Sendable {
  private let lock = NSLock()
  private weak var moduleRef: RCTEventEmitter?
  private var observing = false
  private var pendingClick: [String: Any]?

  func register(_ module: RCTEventEmitter) {
    lock.lock()
    defer { lock.unlock() }
    moduleRef = module
  }

  func setObserving(_ value: Bool) {
    lock.lock()
    defer { lock.unlock() }
    observing = value
  }

  /// Devolve o módulo apto a emitir, ou guarda o clique quando não há ninguém escutando.
  ///
  /// A decisão e a escrita acontecem sob o mesmo lock para que o clique seja entregue
  /// exatamente uma vez — ou pelo evento, ou pelo `getInitialNotificationClick`.
  func moduleForDelivery(orHold payload: [String: Any]) -> RCTEventEmitter? {
    lock.lock()
    defer { lock.unlock() }
    guard observing, let module = moduleRef else {
      // Só o último clique é guardado — um cold start vem de um toque só.
      pendingClick = payload
      return nil
    }
    return module
  }

  /// Devolve o clique guardado e o descarta, para que ele saia daqui uma única vez.
  func takePendingClick() -> [String: Any]? {
    lock.lock()
    defer { lock.unlock() }
    let pending = pendingClick
    pendingClick = nil
    return pending
  }
}

@objc(DitoSdkModule)
class DitoSdkModule: RCTEventEmitter {

  /// Nome do evento; espelha `NOTIFICATION_CLICK_EVENT` no TypeScript.
  private static let notificationClickEvent = "dito_notification_click"

  private static let clickState = DitoClickBridgeState()

  override init() {
    super.init()
    DitoSdkModule.clickState.register(self)
  }

  static func moduleName() -> String! {
    return "DitoSdkModule"
  }

  static func requiresMainQueueSetup() -> Bool {
    return false
  }

  override func supportedEvents() -> [String]! {
    return [DitoSdkModule.notificationClickEvent]
  }

  override func startObserving() {
    DitoSdkModule.clickState.setObserving(true)
  }

  override func stopObserving() {
    DitoSdkModule.clickState.setObserving(false)
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
    let received = Dito.notificationClick(userInfo: userInfo, callback: callback)
    emitNotificationClickEvent(userInfo: userInfo, received: received)
    return true
  }

  /// Mesmo que acima, levando `UNNotificationResponse.actionIdentifier` para o SDK saber
  /// qual botão foi tocado. O SDK descarta os identifiers de default/dismiss do sistema,
  /// então um toque no corpo continua sendo tratado como clique comum.
  ///
  /// Este é o ponto de entrada recomendado: é o único que sabe qual botão foi tocado, e
  /// portanto o único que faz o evento em JavaScript trazer `actionId`/`actionLabel`.
  @objc(didReceiveNotificationClickWithResponse:callback:)
  @discardableResult
  public static func didReceiveNotificationClick(
    response: UNNotificationResponse,
    callback: ((String) -> Void)? = nil
  ) -> Bool {
    let userInfo = response.notification.request.content.userInfo
    guard isDitoChannel(userInfo) else {
      return false
    }
    let received = Dito.notificationClick(response: response, callback: callback)
    emitNotificationClickEvent(userInfo: userInfo, received: received)
    return true
  }

  /// Entrega o clique ao JavaScript, ou o guarda quando não há ninguém escutando.
  ///
  /// O deeplink vem de `received.resolvedLink`, que é o link do próprio botão já resolvido
  /// para o iOS num toque em botão, e o deeplink da notificação num toque no corpo. O
  /// resto continua saindo do payload cru: `DitoNotificationReceived` expõe os campos de
  /// push rico publicamente mas mantém `notification`, `reference`, `logId`,
  /// `notificationName` e `userId` como `internal`, então eles não são legíveis daqui.
  private static func emitNotificationClickEvent(
    userInfo: [AnyHashable: Any],
    received: DitoNotificationReceived
  ) {
    let source = (userInfo["data"] as? [AnyHashable: Any]) ?? userInfo

    var payload: [String: Any] = [:]
    payload["deeplink"] = received.resolvedLink
    payload["notificationId"] = stringValue(source, userInfo, "notification")
    // Sempre vazio: `reference` está em retirada e a atribuição ancora em
    // `user_id`. A chave permanece para não quebrar quem já lê este evento.
    payload["reference"] = ""
    payload["logId"] = stringValue(source, userInfo, "log_id")
    payload["notificationName"] = stringValue(source, userInfo, "notification_name")
    payload["userId"] = stringValue(source, userInfo, "user_id")
    payload["actionId"] = received.actionId
    payload["actionLabel"] = received.actionLabel
    payload["customData"] = received.customData

    guard let module = clickState.moduleForDelivery(orHold: payload) else {
      return
    }
    DispatchQueue.main.async {
      module.sendEvent(withName: notificationClickEvent, body: payload)
    }
  }

  /// Lê a chave no `data` aninhado e, se não achar, no topo do payload.
  private static func stringValue(
    _ nested: [AnyHashable: Any],
    _ root: [AnyHashable: Any],
    _ key: String
  ) -> String {
    if let value = nested[key] as? String {
      return value
    }
    return root[key] as? String ?? ""
  }

  @objc
  func getInitialNotificationClick(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    resolve(DitoSdkModule.clickState.takePendingClick())
  }

  @objc
  func getNotifications(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    let maps: [[String: Any]] = Dito.shared.getNotifications().map { info in
      [
        "id": info.id,
        "notificationId": info.notificationId,
        // Sempre vazio: `reference` foi retirado do payload e a atribuição
        // ancora em `user_id`. A chave fica no mapa para não quebrar quem já
        // lê este evento em JavaScript.
        "reference": "",
        "title": info.title,
        "message": info.message,
        "link": info.link,
        // Epoch em milissegundos nas duas plataformas, para o TypeScript ter um só formato.
        "receivedAt": Int64(info.receivedAt.timeIntervalSince1970 * 1000),
        "isRead": info.isRead,
        "image": info.image,
        "customData": info.customData
      ]
    }
    resolve(maps)
  }

  @objc
  func markNotificationAsRead(_ id: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    if id.isEmpty {
      reject("INVALID_PARAMETERS", "id is required and cannot be empty", nil)
      return
    }
    Dito.shared.markNotificationAsRead(id: id)
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
}
