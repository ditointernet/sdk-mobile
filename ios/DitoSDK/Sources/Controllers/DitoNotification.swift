import Foundation
import UserNotifications

class DitoNotification {

    var options: DitoNotificationOptions = DitoNotificationOptions()

    private let notificationOffline: DitoNotificationOffline
    private let mapper = ActivityMapper()
    private let client: MobileIngestClientProtocol

    init(
        notificationOffline: DitoNotificationOffline = .init(),
        client: MobileIngestClientProtocol? = nil
    ) {
        self.notificationOffline = notificationOffline
        self.client = client ?? MobileIngestClient.buildFromDitoConfig()
    }

    func makeNotificationContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = options.soundName.map { UNNotificationSound(named: UNNotificationSoundName($0)) } ?? .default
        return content
    }

    func registerToken(token: String) {
        #if DEBUG
        DitoLogger.information("📱 [REGISTER TOKEN] token=\(token.prefix(20))...")
        #endif

        if notificationOffline.isSaving {
            #if DEBUG
            DitoLogger.debug("⏳ [REGISTER TOKEN] Aguardando identify completar...")
            #endif
            notificationOffline.setRegisterAsCompletion {
                DispatchQueue.global().async {
                    self.processTokenRegistration(token: token)
                }
            }
        } else {
            DispatchQueue.global().async {
                self.processTokenRegistration(token: token)
            }
        }
    }

    private func processTokenRegistration(token: String) {
        guard let userId = notificationOffline.reference, !userId.isEmpty else {
            let tokenRequest = makeTokenRequest(token: token)
            notificationOffline.notificationRegister(tokenRequest)
            DitoLogger.warning("⚠️ [REGISTER TOKEN] Usuário não identificado - salvando offline")
            return
        }
        Task {
            let activity = mapper.mapFromTokenRequest(makeTokenRequest(token: token), isRegister: true)
            let request = mapper.buildRequest(userId: userId, activities: [activity])
            do {
                try await client.activity(request)
                DitoLogger.information("✅ [REGISTER TOKEN] Sucesso")
            } catch {
                notificationOffline.notificationRegister(makeTokenRequest(token: token))
                DitoLogger.error(error.localizedDescription)
            }
        }
    }

    func unregisterToken(token: String) {
        #if DEBUG
        DitoLogger.information("📴 [UNREGISTER TOKEN] token=\(token.prefix(20))...")
        #endif

        if notificationOffline.isSaving {
            notificationOffline.setRegisterAsCompletion {
                DispatchQueue.global().async {
                    self.processTokenUnregistration(token: token)
                }
            }
        } else {
            DispatchQueue.global().async {
                self.processTokenUnregistration(token: token)
            }
        }
    }

    private func processTokenUnregistration(token: String) {
        guard let userId = notificationOffline.reference, !userId.isEmpty else {
            notificationOffline.notificationUnregister(makeTokenRequest(token: token))
            DitoLogger.warning("⚠️ [UNREGISTER TOKEN] Usuário não identificado - salvando offline")
            return
        }
        Task {
            let activity = mapper.mapFromTokenRequest(makeTokenRequest(token: token), isRegister: false)
            let request = mapper.buildRequest(userId: userId, activities: [activity])
            do {
                try await client.activity(request)
                DitoLogger.information("✅ [UNREGISTER TOKEN] Sucesso")
            } catch {
                notificationOffline.notificationUnregister(makeTokenRequest(token: token))
                DitoLogger.error(error.localizedDescription)
            }
        }
    }

    func notificationRead(with userInfo: [AnyHashable: Any]) {
        DispatchQueue.global(qos: .background).async {
            let notificationData = DitoDataNotification(from: userInfo)
            let notificationRequest = self.makeNotificationRequest(data: notificationData)

            #if DEBUG
            DitoLogger.information("🔔 [NOTIFICATION RECEIVED] id=\(notificationData.notification)")
            #endif

            self.notificationOffline.notificationRead(notificationRequest)
        }
    }

    func notificationClick(notificationId: String, reference: String, identifier: String) {
        #if DEBUG
        DitoLogger.information("👆 [NOTIFICATION CLICK] id=\(notificationId)")
        #endif

        guard !notificationId.isEmpty else { return }

        Task {
            await processNotificationClick(
                notificationId: notificationId,
                reference: reference,
                identifier: identifier
            )
        }
    }

    private func processNotificationClick(notificationId: String, reference: String, identifier: String) async {
        guard !identifier.isEmpty else {
            DitoLogger.warning("⚠️ [NOTIFICATION CLICK] identifier vazio; operação cancelada")
            return
        }
        let activity = mapper.mapNotificationClick(notificationId: notificationId, identifier: identifier)
        let request = mapper.buildRequest(userId: identifier, activities: [activity])
        do {
            try await client.activity(request)
            DitoLogger.information("✅ [NOTIFICATION CLICK] Sucesso")
        } catch {
            DitoLogger.error(error.localizedDescription)
            let data = DitoDataNotification(
                identifier: identifier,
                reference: reference,
                notification: notificationId,
                notificationLogId: "",
                userId: identifier,
                deviceType: "",
                channel: "",
                notificationName: "",
                title: "",
                message: "",
                link: "",
                logId: ""
            )
            let openRequest = makeNotificationRequest(data: data)
            Task {
                self.notificationOffline.notificationRead(openRequest)
            }
        }
    }

    private func makeTokenRequest(token: String) -> DitoTokenRequest {
        DitoTokenRequest(
            platformAppKey: Dito.appKey.isEmpty ? Dito.apiKey : Dito.appKey,
            sha1Signature: Dito.signature,
            token: token
        )
    }

    private func makeNotificationRequest(data: DitoDataNotification) -> DitoNotificationOpenRequest {
        DitoNotificationOpenRequest(
            platformAppKey: Dito.appKey.isEmpty ? Dito.apiKey : Dito.appKey,
            sha1Signature: Dito.signature,
            data: data
        )
    }
}
