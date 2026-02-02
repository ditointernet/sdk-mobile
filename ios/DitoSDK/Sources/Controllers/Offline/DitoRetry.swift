import CoreData
import Foundation

extension DitoRetry {
  struct TrackData: Sendable {
    let id: NSManagedObjectID
    let eventJSON: String
    let retry: Int16
  }

  struct NotificationData: Sendable {
    let id: NSManagedObjectID
    let json: String?
    let retry: Int16
  }
}

class DitoRetry {

  private var identifyOffline: DitoIdentifyOffline
  private var trackOffline: DitoTrackOffline
  private var notificationReadOffline: DitoNotificationOffline
  private let serviceIdentify: DitoIdentifyService
  private let serviceTrack: DitoTrackService
  private let serviceNotification: DitoNotificationService

  init(
    identifyOffline: DitoIdentifyOffline = .shared,
    trackOffline: DitoTrackOffline = .init(),
    notificationOffline: DitoNotificationOffline = .init(),
    serviceNotification: DitoNotificationService = .init(),
    serviceIdentify: DitoIdentifyService = .init(),
    serviceTrack: DitoTrackService = .init()
  ) {

    self.identifyOffline = identifyOffline
    self.trackOffline = trackOffline
    self.notificationReadOffline = notificationOffline
    self.serviceIdentify = serviceIdentify
    self.serviceTrack = serviceTrack
    self.serviceNotification = serviceNotification
  }

  func loadOffline() {
    Task {
      let identifySuccess = await checkIdentify()
      if identifySuccess {
        await withTaskGroup(of: Void.self) { group in
          group.addTask { await self.checkTrack() }
          group.addTask { await self.checkNotification() }
          group.addTask { await self.checkNotificationRegister() }
          group.addTask { await self.checkNotificationUnregister() }
        }
      }
    }
  }

  private func checkIdentify() async -> Bool {
    guard let identify = self.identifyOffline.getIdentify,
      let id = identify.id,
      let signupRequest = identify.json?.convertToObject(
        type: DitoSignupRequest.self
      )
    else {
      return false
    }

    if !identify.send {
      #if DEBUG
      DitoLogger.debug("🔄 [RETRY] Reenviando identify offline para id=\(id)")
      #endif

      return await withCheckedContinuation { continuation in
        self.serviceIdentify.signup(
          network: "portal",
          id: id,
          data: signupRequest
        ) { [weak self] (identify, error) in
          guard let self = self else {
            continuation.resume(returning: false)
            return
          }
          if let error = error {
            DitoLogger.error(error.localizedDescription)
            continuation.resume(returning: false)
          } else {
            if let reference = identify?.reference {
              self.identifyOffline.update(
                id: id,
                params: signupRequest,
                reference: reference,
                send: true
              )
              DitoLogger.information("Identify realizado")
              continuation.resume(returning: true)
            } else {
              continuation.resume(returning: false)
            }
          }
        }
      }
    } else {
      return true
    }
  }

  private func checkTrack() async {
    let tracks = self.trackOffline.getTrack

    #if DEBUG
    if !tracks.isEmpty {
      DitoLogger.debug("🔄 [RETRY] Verificando \(tracks.count) evento(s) offline para reenvio")
    }
    #endif

    for track in tracks {
      guard let eventJSON = track.event else { continue }
      let trackId = track.objectID
      let currentRetry = track.retry

      guard
        let eventRequest = eventJSON.convertToObject(
          type: DitoEventRequest.self
        )
      else {
        DitoLogger.error(
          "Falha ao decodificar DitoEventRequest do JSON salvo"
        )
        continue
      }

      #if DEBUG
      DitoLogger.debug("🔄 [RETRY] Reenviando evento: \(eventRequest.event.action) (tentativa \(currentRetry + 1))")
      #endif

      if let reference = self.trackOffline.reference, !reference.isEmpty {
        await sendEventAsync(
          objectID: trackId,
          eventJSON: eventJSON,
          retry: currentRetry
        )
      } else {
        self.trackOffline.update(
          id: trackId,
          event: eventRequest,
          retry: currentRetry + 1
        )
        DitoLogger.warning(
          "Track - Antes de enviar um evento é preciso identificar o usuário."
        )
      }
    }
  }

  private func sendEventAsync(
    objectID: NSManagedObjectID,
    eventJSON: String,
    retry: Int16
  ) async {
    guard
      let eventRequest = eventJSON.convertToObject(
        type: DitoEventRequest.self
      )
    else { return }
    let id = objectID

    if let reference = trackOffline.reference, !reference.isEmpty {
      await withCheckedContinuation { continuation in
        serviceTrack.event(reference: reference, data: eventRequest) {
          [weak self] (_, error) in
          guard let self = self else {
            continuation.resume()
            return
          }
          if let error = error {
            self.trackOffline.update(
              id: id,
              event: eventRequest,
              retry: retry + 1
            )
            DitoLogger.error(error.localizedDescription)
          } else {
            self.trackOffline.delete(id: id)
            DitoLogger.information("Track - Evento enviado")
          }
          continuation.resume()
        }
      }
    } else {
      trackOffline.update(id: id, event: eventRequest, retry: retry + 1)
      DitoLogger.warning(
        "Track - Antes de enviar um evento é preciso identificar o usuário."
      )
    }
  }

  private func checkNotification() async {
    let notifications = self.notificationReadOffline.getNotificationRead

    #if DEBUG
    if !notifications.isEmpty {
      DitoLogger.debug("🔄 [RETRY] Verificando \(notifications.count) notificação(ões) read offline para reenvio")
    }
    #endif

    for notification in notifications {
      let notifID = notification.objectID
      let jsonData = notification.json
      let notifRetry = notification.retry

      guard let notificationRead = jsonData,
        let notificationRequest = notificationRead.convertToObject(
          type: DitoNotificationOpenRequest.self
        )
      else {
        continue
      }

      let notificationId = notificationRequest.data.notification

      #if DEBUG
      DitoLogger.debug("🔄 [RETRY] Reenviando notification read: \(notificationId) (tentativa \(notifRetry + 1))")
      #endif

      if let reference = self.notificationReadOffline.reference,
        !reference.isEmpty, !notificationId.isEmpty
      {
        await withCheckedContinuation { continuation in
          self.serviceNotification.read(
            notificationId: notificationId,
            data: notificationRequest
          ) { [weak self] (register, error) in

            guard let self = self else {
              continuation.resume()
              return
            }
            if let error = error {
              self.notificationReadOffline.updateRead(
                id: notifID,
                retry: notifRetry + 1
              )
              DitoLogger.error(error.localizedDescription)
            } else {
              self.notificationReadOffline.deleteRead(id: notifID)
              DitoLogger.information(
                "Notification Read - Deletado"
              )
            }
            continuation.resume()
          }
        }
      } else {
        DitoLogger.warning(
          "Notification Read - Antes de informar uma notifição lida é preciso identificar o usuário."
        )
      }
    }
  }

  private func checkNotificationRegister() async {
    if let reference = self.notificationReadOffline.reference,
      !reference.isEmpty
    {
      guard
        let notificationRegister = self.notificationReadOffline
          .getNotificationRegister,
        let registerJson = notificationRegister.json,
        let registerRequest = registerJson.convertToObject(
          type: DitoTokenRequest.self
        )
      else {
        return
      }

      #if DEBUG
      DitoLogger.debug("🔄 [RETRY] Reenviando register token offline (tentativa \(notificationRegister.retry + 1))")
      #endif

      let tokenRequest = DitoTokenRequest(
        platformAppKey: registerRequest.platformAppKey,
        sha1Signature: registerRequest.sha1Signature,
        token: registerRequest.token
      )

      await withCheckedContinuation { continuation in
        self.serviceNotification.register(
          reference: reference,
          data: tokenRequest
        ) { [weak self] (register, error) in
          guard let self = self else {
            continuation.resume()
            return
          }
          if let error = error {
            self.notificationReadOffline.updateRegister(
              id: nil,
              retry: notificationRegister.retry + 1
            )
            DitoLogger.error(error.localizedDescription)
          } else {
            self.notificationReadOffline.deleteRegister()
            DitoLogger.information(
              "Notification - Token registrado"
            )
          }
          continuation.resume()
        }
      }
    } else {
      DitoLogger.warning(
        "Register Token - Antes de registrar o token é preciso identificar o usuário."
      )
    }
  }

  private func checkNotificationUnregister() async {
    if let reference = self.notificationReadOffline.reference,
      !reference.isEmpty
    {
      guard
        let notificationRegister = self.notificationReadOffline
          .getNotificationUnregister,
        let registerJson = notificationRegister.json,
        let registerRequest = registerJson.convertToObject(
          type: DitoTokenRequest.self
        )
      else {
        return
      }

      #if DEBUG
      DitoLogger.debug("🔄 [RETRY] Reenviando unregister token offline (tentativa \(notificationRegister.retry + 1))")
      #endif

      let tokenRequest = DitoTokenRequest(
        platformAppKey: registerRequest.platformAppKey,
        sha1Signature: registerRequest.sha1Signature,
        token: registerRequest.token
      )

      await withCheckedContinuation { continuation in
        self.serviceNotification.unregister(
          reference: reference,
          data: tokenRequest
        ) { [weak self] (register, error) in
          guard let self = self else {
            continuation.resume()
            return
          }
          if let error = error {
            self.notificationReadOffline.updateUnregister(
              id: notificationRegister.objectID,
              retry: notificationRegister.retry + 1
            )
            DitoLogger.error(error.localizedDescription)
          } else {
            self.notificationReadOffline.deleteUnregister()
            DitoLogger.information(
              "Notification - Token registrado"
            )
          }
          continuation.resume()
        }
      }
    } else {
      DitoLogger.warning(
        "Register Token - Antes de registrar o token é preciso identificar o usuário."
      )
    }
  }
}
