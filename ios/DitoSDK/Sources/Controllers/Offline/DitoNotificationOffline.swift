import CoreData
import Foundation

struct DitoNotificationOffline {

  private var notificationRegisterDataManager: DitoNotificationRegisterDataManager
  private var notificationUnregisterDataManager: DitoNotificationUnregisterDataManager
  private var notificationDataManager: DitoNotificationReadDataManager
  private var notificationReceiveDataManager: DitoNotificationReceiveDataManager
  private let identifyOffline: DitoIdentifyOffline

  init(
    notificationReadDataManager: DitoNotificationReadDataManager = .init(),
    notificationReceiveDataManager: DitoNotificationReceiveDataManager = .init(),
    notificationRegisterDataManager: DitoNotificationRegisterDataManager =
      .init(),
    notificationUnregisterDataManager:
      DitoNotificationUnregisterDataManager = .init(),
    identifyOffline: DitoIdentifyOffline = .shared
  ) {

    self.notificationUnregisterDataManager =
      notificationUnregisterDataManager
    self.notificationRegisterDataManager = notificationRegisterDataManager
    self.notificationDataManager = notificationReadDataManager
    self.notificationReceiveDataManager = notificationReceiveDataManager
    self.identifyOffline = identifyOffline
  }

  func notificationRegister(_ notification: DitoTokenRequest) {
    let json = notification.toString
    self.notificationRegisterDataManager.save(with: json)
  }

  func notificationUnregister(_ notification: DitoTokenRequest) {
    let json = notification.toString
    self.notificationUnregisterDataManager.save(with: json)
  }

  func notificationRead(_ notification: DitoNotificationOpenRequest) {
    DitoLogger.information(
      "Notification - Salvando a notifação em offline"
    )
    DitoLogger.debug(notification)
    let json = notification.toString
    self.notificationDataManager.save(with: json)
  }

  func notificationReceive(_ pending: DitoNotificationReceivePending) {
    DitoLogger.information("Notification receive - salvando receive-ios-notification em offline")
    let json = pending.toString
    notificationReceiveDataManager.save(with: json)
  }

  var getNotificationReceive: [DitoNotificationReceiveRow] {
    notificationReceiveDataManager.fetchAll
  }

  func updateReceive(id: NSManagedObjectID, retry: Int16) {
    notificationReceiveDataManager.update(id: id, retry: retry)
  }

  func deleteReceive(id: NSManagedObjectID) {
    notificationReceiveDataManager.delete(with: id)
  }

  func setRegisterAsCompletion(_ completion: @escaping () -> Void) {
    identifyOffline.setIdentityCompletionClosure(completion)
  }

  var isSaving: Bool {
    return identifyOffline.getSavingState
  }

  var reference: String? {
    return identifyOffline.getIdentify?.reference
  }

  var getNotificationRegister: NotificationDefaults? {
    return notificationRegisterDataManager.fetch
  }

  func updateRegister(id: NSManagedObjectID? = nil, retry: Int16) {
    notificationRegisterDataManager.update(id: id, retry: retry)
  }

  func deleteRegister() {
    notificationRegisterDataManager.delete()
  }

  var getNotificationUnregister: DitoNotificationUnregisterRow? {
    return notificationUnregisterDataManager.fetch
  }

  func updateUnregister(id: NSManagedObjectID, retry: Int16) {
    notificationUnregisterDataManager.update(id: id, retry: retry)
  }

  func deleteUnregister() {
    notificationUnregisterDataManager.delete()
  }

  var getNotificationRead: [DitoNotificationReadRow] {
    return notificationDataManager.fetchAll
  }

  func updateRead(id: NSManagedObjectID, retry: Int16) {
    notificationDataManager.update(id: id, retry: retry)
  }

  func deleteRead(id: NSManagedObjectID) {
    notificationDataManager.delete(with: id)
  }
}
