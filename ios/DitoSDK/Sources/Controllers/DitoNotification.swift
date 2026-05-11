import Foundation
import UIKit
import UserNotifications

class DitoNotification {

    var options: DitoNotificationOptions = DitoNotificationOptions()

    private let notificationOffline: DitoNotificationOffline
    private let mapper = ActivityMapper()
    private let client: MobileIngestClientProtocol
    var badgeUpdater: (_ delta: Int) -> Void

    init(notificationOffline: DitoNotificationOffline = .init()) {
        self.notificationOffline = notificationOffline
        self.client = MobileIngestClient.buildFromDitoConfig()
        self.badgeUpdater = { delta in
            DispatchQueue.main.async {
                let current = UIApplication.shared.applicationIconBadgeNumber
                let newValue = max(0, current + delta)
                UNUserNotificationCenter.current().setBadgeCount(newValue) { _ in }
            }
        }
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
        if options.badgeEnabled {
            badgeUpdater(+1)
        }

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

        if options.badgeEnabled {
            badgeUpdater(-1)
        }

        DispatchQueue.global(qos: .background).async {
            self.processNotificationClick(notificationId: notificationId, reference: reference, identifier: identifier)
        }
    }

    private func processNotificationClick(notificationId: String, reference: String, identifier: String) {
        Task {
            guard !identifier.isEmpty else { return }
            let activity = mapper.mapNotificationClick(notificationId: notificationId, identifier: identifier)
            let request = mapper.buildRequest(userId: identifier, activities: [activity])
            do {
                try await client.activity(request)
                DitoLogger.information("✅ [NOTIFICATION CLICK] Sucesso")
            } catch {
                DitoLogger.error(error.localizedDescription)
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
