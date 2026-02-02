//
//  DitoNotification.swift
//  DitoSDK
//
//  Created by Rodrigo Damacena Gamarra Maciel on 27/01/21.
//

import Foundation

class DitoNotification {

  private let service: DitoNotificationService
  private let notificationOffline: DitoNotificationOffline

  init(service: DitoNotificationService = .init(), trackOffline: DitoNotificationOffline = .init())
  {
    self.service = service
    self.notificationOffline = trackOffline
  }

  /// Registers a Firebase Cloud Messaging (FCM) token
  /// - Parameter token: The FCM token from Firebase Messaging
  func registerToken(token: String) {
    #if DEBUG
    DitoLogger.information("📱 [REGISTER TOKEN] token=\(token.prefix(20))...")
    #endif

    let appKey = Dito.appKey
    let signature = Dito.signature

    if notificationOffline.isSaving {
      #if DEBUG
      DitoLogger.debug("⏳ [REGISTER TOKEN] Aguardando identify completar...")
      #endif
      notificationOffline.setRegisterAsCompletion {
        DispatchQueue.global().async {
          let tokenRequest = self.createTokenRequest(appKey: appKey, signature: signature, token: token)
          self.processTokenRegistration(tokenRequest: tokenRequest)
        }
      }
    } else {
      DispatchQueue.global().async {
        let tokenRequest = self.createTokenRequest(appKey: appKey, signature: signature, token: token)
        self.processTokenRegistration(tokenRequest: tokenRequest)
      }
    }
  }

  private func createTokenRequest(appKey: String, signature: String, token: String) -> DitoTokenRequest {
    DitoTokenRequest(platformAppKey: appKey, sha1Signature: signature, token: token)
  }

  private func processTokenRegistration(tokenRequest: DitoTokenRequest) {
      guard let reference = notificationOffline.reference, !reference.isEmpty else {
      notificationOffline.notificationRegister(tokenRequest)
      DitoLogger.warning("⚠️ [REGISTER TOKEN] Usuário não identificado - salvando offline")
      return
    }

    service.register(reference: reference, data: tokenRequest) { [weak self] (register, error) in
      guard let self = self else { return }
      if let error = error {
        self.notificationOffline.notificationRegister(tokenRequest)
        DitoLogger.error(error.localizedDescription)
      } else {
        DitoLogger.information("✅ [REGISTER TOKEN] Sucesso")
      }
    }
  }

  /// Unregisters a Firebase Cloud Messaging (FCM) token
  /// - Parameter token: The FCM token to unregister
  func unregisterToken(token: String) {
    #if DEBUG
    DitoLogger.information("📴 [UNREGISTER TOKEN] token=\(token.prefix(20))...")
    #endif

    let appKey = Dito.appKey
    let signature = Dito.signature

    if notificationOffline.isSaving {
      #if DEBUG
      DitoLogger.debug("⏳ [UNREGISTER TOKEN] Aguardando identify completar...")
      #endif
      notificationOffline.setRegisterAsCompletion {
        DispatchQueue.global().async {
          let tokenRequest = self.createTokenRequest(appKey: appKey, signature: signature, token: token)
          self.processTokenUnregistration(tokenRequest: tokenRequest)
        }
      }
    } else {
      DispatchQueue.global().async {
        let tokenRequest = self.createTokenRequest(appKey: appKey, signature: signature, token: token)
        self.processTokenUnregistration(tokenRequest: tokenRequest)
      }
    }
  }

  private func processTokenUnregistration(tokenRequest: DitoTokenRequest) {
    guard let reference = notificationOffline.reference, !reference.isEmpty else {
      notificationOffline.notificationUnregister(tokenRequest)
      DitoLogger.warning("⚠️ [UNREGISTER TOKEN] Usuário não identificado - salvando offline")
      return
    }

    service.unregister(reference: reference, data: tokenRequest) { [weak self] (register, error) in
      guard let self = self else { return }
      if let error = error {
        self.notificationOffline.notificationUnregister(tokenRequest)
        DitoLogger.error(error.localizedDescription)
      } else {
        DitoLogger.information("✅ [UNREGISTER TOKEN] Sucesso")
      }
    }
  }

  /// Called when notification is received (before click)
  /// - Parameter userInfo: The notification data dictionary
  func notificationRead(with userInfo: [AnyHashable: Any]) {
    let appKey = Dito.appKey
    let signature = Dito.signature
    DispatchQueue.global(qos: .background).async {
      let notificationData = self.createNotificationData(from: userInfo)

      #if DEBUG
      DitoLogger.information("🔔 [NOTIFICATION RECEIVED] id=\(notificationData.notification)")
      #endif

      let notificationRequest = self.createNotificationRequest(appKey: appKey, signature: signature, data: notificationData)
      self.processNotificationRead(notificationData: notificationData, notificationRequest: notificationRequest)
    }
  }

  private func createNotificationData(from userInfo: [AnyHashable: Any]) -> DitoDataNotification {
    DitoDataNotification(from: userInfo)
  }

  private func createNotificationRequest(appKey: String, signature: String, data: DitoDataNotification) -> DitoNotificationOpenRequest {
    DitoNotificationOpenRequest(
      platformAppKey: appKey,
      sha1Signature: signature,
      data: data
    )
  }

  private func processNotificationRead(notificationData: DitoDataNotification, notificationRequest: DitoNotificationOpenRequest) {
    notificationOffline.notificationRead(notificationRequest)
  }

  /// Called when notification is clicked
  /// - Parameters:
  ///   - notificationId: The notification ID
  ///   - reference: The user reference
  ///   - identifier: The identifier
  func notificationClick(notificationId: String, reference: String, identifier: String) {
    #if DEBUG
    DitoLogger.information("👆 [NOTIFICATION CLICK] id=\(notificationId)")
    #endif

    let appKey = Dito.appKey
    let signature = Dito.signature
    DispatchQueue.global(qos: .background).async {
      let data = self.createNotificationData(identifier: identifier, reference: reference)
      let notificationRequest = self.createNotificationRequest(appKey: appKey, signature: signature, data: data)
      self.processNotificationClick(notificationId: notificationId, notificationRequest: notificationRequest)
    }
  }

  private func createNotificationData(identifier: String, reference: String) -> DitoDataNotification {
    DitoDataNotification(identifier: identifier, reference: reference)
  }

  private func processNotificationClick(notificationId: String, notificationRequest: DitoNotificationOpenRequest) {
    guard !notificationId.isEmpty else { return }

    service.read(notificationId: notificationId, data: notificationRequest) { [weak self] (register, error) in
      guard let self = self else { return }
      if let error = error {
        self.notificationOffline.notificationRead(notificationRequest)
        DitoLogger.error(error.localizedDescription)
      } else {
        DitoLogger.information("✅ [NOTIFICATION CLICK] Sucesso")
      }
    }
  }

}
