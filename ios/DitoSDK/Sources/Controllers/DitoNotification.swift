import DitoSDKNotificationService
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
        #if DEBUG
        self.client = client ?? Self.testMobileIngestClient ?? MobileIngestClient.buildFromDitoConfig()
        #else
        self.client = client ?? MobileIngestClient.buildFromDitoConfig()
        #endif
    }

    func makeNotificationContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = options.soundName.map { UNNotificationSound(named: UNNotificationSoundName($0)) } ?? .default
        return content
    }

    func registerToken(
        token: String,
        completion: ((Result<DitoOperationStatus, Error>) -> Void)? = nil
    ) {
        #if DEBUG
        DitoLogger.information("📱 [REGISTER TOKEN] token=\(token.prefix(20))...")
        #endif

        if notificationOffline.isSaving {
            #if DEBUG
            DitoLogger.debug("⏳ [REGISTER TOKEN] Aguardando identify completar...")
            #endif
            notificationOffline.setRegisterAsCompletion {
                DispatchQueue.global().async {
                    self.processTokenRegistration(token: token, completion: completion)
                }
            }
        } else {
            DispatchQueue.global().async {
                self.processTokenRegistration(token: token, completion: completion)
            }
        }
    }

    private func processTokenRegistration(
        token: String,
        completion: ((Result<DitoOperationStatus, Error>) -> Void)?
    ) {
        guard let userId = notificationOffline.reference, !userId.isEmpty else {
            let tokenRequest = makeTokenRequest(token: token)
            notificationOffline.notificationRegister(tokenRequest)
            DitoLogger.warning("⚠️ [REGISTER TOKEN] Usuário não identificado - salvando offline")
            completion?(.success(.savedLocally))
            return
        }
        Task {
            let activity = mapper.mapFromTokenRequest(makeTokenRequest(token: token), isRegister: true)
            let request = mapper.buildRequest(userId: userId, activities: [activity])
            do {
                try await client.activity(request)
                DitoLogger.information("✅ [REGISTER TOKEN] Sucesso")
                completion?(.success(.sent))
            } catch {
                notificationOffline.notificationRegister(makeTokenRequest(token: token))
                DitoLogger.error(error.localizedDescription)
                completion?(.success(.savedLocally))
            }
        }
    }

    func unregisterToken(
        token: String,
        completion: ((Result<DitoOperationStatus, Error>) -> Void)? = nil
    ) {
        #if DEBUG
        DitoLogger.information("📴 [UNREGISTER TOKEN] token=\(token.prefix(20))...")
        #endif

        if notificationOffline.isSaving {
            notificationOffline.setRegisterAsCompletion {
                DispatchQueue.global().async {
                    self.processTokenUnregistration(token: token, completion: completion)
                }
            }
        } else {
            DispatchQueue.global().async {
                self.processTokenUnregistration(token: token, completion: completion)
            }
        }
    }

    private func processTokenUnregistration(
        token: String,
        completion: ((Result<DitoOperationStatus, Error>) -> Void)?
    ) {
        guard let userId = notificationOffline.reference, !userId.isEmpty else {
            notificationOffline.notificationUnregister(makeTokenRequest(token: token))
            DitoLogger.warning("⚠️ [UNREGISTER TOKEN] Usuário não identificado - salvando offline")
            completion?(.success(.savedLocally))
            return
        }
        Task {
            let activity = mapper.mapFromTokenRequest(makeTokenRequest(token: token), isRegister: false)
            let request = mapper.buildRequest(userId: userId, activities: [activity])
            do {
                try await client.activity(request)
                DitoLogger.information("✅ [UNREGISTER TOKEN] Sucesso")
                completion?(.success(.sent))
            } catch {
                notificationOffline.notificationUnregister(makeTokenRequest(token: token))
                DitoLogger.error(error.localizedDescription)
                completion?(.success(.savedLocally))
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
            // Full payload dump, behind DitoPushDebugLog's flag. The extension
            // emits the same line from its own process with source="nse".
            DitoPushDebugLog.dump(source: .app, userInfo: userInfo)

            self.notificationOffline.notificationRead(notificationRequest)
        }
    }

    /// - Parameter data: extra custom data for the click event. For an action
    ///   button tap it carries `action_id` / `action_label` (D-03).
    func notificationClick(
        notificationId: String,
        reference: String,
        identifier: String,
        data: [String: String] = [:]
    ) {
        #if DEBUG
        let action = data["action_id"].map { " action=\($0)" } ?? ""
        DitoLogger.information("👆 [NOTIFICATION CLICK] id=\(notificationId)\(action)")
        #endif

        guard !notificationId.isEmpty else { return }

        Task {
            await processNotificationClick(
                notificationId: notificationId,
                reference: reference,
                identifier: identifier,
                data: data
            )
        }
    }

    private func processNotificationClick(
        notificationId: String,
        reference: String,
        identifier: String,
        data: [String: String] = [:]
    ) async {
        guard !identifier.isEmpty else {
            DitoLogger.warning("⚠️ [NOTIFICATION CLICK] identifier vazio; operação cancelada")
            return
        }
        let activity = mapper.mapNotificationClick(
            notificationId: notificationId,
            identifier: identifier,
            data: data
        )
        let request = mapper.buildRequest(userId: identifier, activities: [activity])
        do {
            try await client.activity(request)
            DitoLogger.information("✅ [NOTIFICATION CLICK] Sucesso")
        } catch {
            DitoLogger.error(error.localizedDescription)
            // Keep the rich-push context so a replayed click still reports
            // which button was tapped.
            var customData = data
            let actionId = customData.removeValue(forKey: "action_id") ?? ""
            let actionLabel = customData.removeValue(forKey: "action_label") ?? ""
            let notificationData = DitoDataNotification(
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
                logId: "",
                customData: customData,
                actionId: actionId,
                actionLabel: actionLabel
            )
            let openRequest = makeNotificationRequest(data: notificationData)
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

#if DEBUG
extension DitoNotification {
    static var testMobileIngestClient: MobileIngestClientProtocol?
}
#endif
