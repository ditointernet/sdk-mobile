import DitoSDKNotificationService
import Foundation
import UserNotifications

class DitoNotification {

    var options: DitoNotificationOptions = DitoNotificationOptions()

    private let notificationOffline: DitoNotificationOffline
    private let mapper = ActivityMapper()
    private let client: MobileIngestClientProtocol
    private let onSent: () -> Void

    init(
        notificationOffline: DitoNotificationOffline = .init(),
        client: MobileIngestClientProtocol? = nil,
        onSent: @escaping () -> Void = Dito.flushOfflineQueue
    ) {
        self.notificationOffline = notificationOffline
        self.onSent = onSent
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

        UserDefaults.lastPushToken = token

        if notificationOffline.isSaving {
            #if DEBUG
            DitoLogger.debug("⏳ [REGISTER TOKEN] Aguardando identify completar...")
            #endif
            notificationOffline.setRegisterAsCompletion {
                DispatchQueue.global().async {
                    self.processToken(token: token, isRegister: true, completion: completion)
                }
            }
        } else {
            DispatchQueue.global().async {
                self.processToken(token: token, isRegister: true, completion: completion)
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

        if UserDefaults.lastPushToken == token {
            UserDefaults.lastPushToken = nil
        }
        if UserDefaults.lastUserTokenRegister?["token"] == token {
            UserDefaults.lastUserTokenRegister = nil
        }

        if notificationOffline.isSaving {
            notificationOffline.setRegisterAsCompletion {
                DispatchQueue.global().async {
                    self.processToken(token: token, isRegister: false, completion: completion)
                }
            }
        } else {
            DispatchQueue.global().async {
                self.processToken(token: token, isRegister: false, completion: completion)
            }
        }
    }

    func registerLastToken() {
        guard let token = UserDefaults.lastPushToken else { return }
        if case .identified(let userId) = notificationOffline.identityState,
           UserDefaults.lastUserTokenRegister == ["user_id": userId, "token": token] {
            return
        }
        // A queued register of this token with an owner is sent by the retry; sending here too would duplicate it.
        if let pending = notificationOffline.getNotificationRegister, pending.anonymous != true,
           pending.retry < DitoRetry.maxRetries,
           Self.token(of: pending.json) == token {
            return
        }
        registerToken(token: token)
    }

    private static func token(of json: String?) -> String? {
        json?.convertToObject(type: DitoTokenRequest.self)?.token
    }

    private func processToken(
        token: String,
        isRegister: Bool,
        completion: ((Result<DitoOperationStatus, Error>) -> Void)?
    ) {
        // A queued opposite operation on this token would undo this one when the retry sends it.
        if isRegister {
            if let pending = notificationOffline.getNotificationUnregister, Self.token(of: pending.json) == token {
                notificationOffline.deleteUnregister(id: pending.id)
            }
        } else if let pending = notificationOffline.getNotificationRegister, Self.token(of: pending.json) == token {
            notificationOffline.deleteRegister(ifMatching: pending)
        }
        let label = isRegister ? "REGISTER TOKEN" : "UNREGISTER TOKEN"
        let tokenRequest = makeTokenRequest(token: token)
        let state = notificationOffline.identityState
        guard state != .pending else {
            saveTokenOffline(tokenRequest, isRegister: isRegister, anonymous: false)
            DitoLogger.warning("⚠️ [\(label)] Usuário não identificado - salvando offline")
            completion?(.success(.savedLocally))
            return
        }
        Task {
            let activity = mapper.mapFromTokenRequest(tokenRequest, isRegister: isRegister)
            do {
                if case .identified(let userId) = state {
                    try await client.activity(mapper.buildRequest(userId: userId, activities: [activity]))
                    if isRegister, notificationOffline.identityState == state, UserDefaults.lastPushToken == token {
                        UserDefaults.lastUserTokenRegister = ["user_id": userId, "token": token]
                    }
                } else {
                    try await client.sendAnonymous([activity], mapper: mapper)
                }
                if isRegister, let pending = notificationOffline.getNotificationRegister {
                    let pendingToken = DitoNotification.token(of: pending.json)
                    // Same token: already registered, unless the queued one belongs to another identity (a login
                    // or user switch during the send). Other token: dropped only if it isn't the last one.
                    let sameOwner = state == .anonymous
                        ? pending.anonymous == true
                        : notificationOffline.identityState == state
                    let sameTokenSent = pendingToken == token && sameOwner
                    if sameTokenSent || (pendingToken != token && pendingToken != UserDefaults.lastPushToken) {
                        notificationOffline.deleteRegister(ifMatching: pending)
                    }
                }
                DitoLogger.information("✅ [\(label)] Sucesso")
                completion?(.success(.sent))
                onSent()
            } catch {
                if let anonymous = offlineOwner(startedAs: state, token: token, isRegister: isRegister) {
                    saveTokenOffline(tokenRequest, isRegister: isRegister, anonymous: anonymous)
                }
                DitoLogger.error(error.localizedDescription)
                completion?(.success(.savedLocally))
            }
        }
    }

    /// Whether a failed send is queued as anonymous, or nil to drop it. Dropped when a later call superseded it
    /// (a register of a token no longer the last one, an unregister of a token registered again). A send started
    /// anonymous stays anonymous, except a register of the last token after a login: the identify confirmation
    /// re-sends it (`registerLastToken`).
    private func offlineOwner(startedAs state: DitoIdentityState, token: String, isRegister: Bool) -> Bool? {
        guard isRegister == (token == UserDefaults.lastPushToken) else { return nil }
        guard state == .anonymous else { return false }
        guard isRegister else { return true }
        switch notificationOffline.identityState {
        case .anonymous:
            return true
        case .pending:
            return false
        case .identified:
            return nil
        }
    }

    private func saveTokenOffline(_ request: DitoTokenRequest, isRegister: Bool, anonymous: Bool) {
        if isRegister {
            notificationOffline.notificationRegister(request, anonymous: anonymous)
        } else {
            notificationOffline.notificationUnregister(request, anonymous: anonymous)
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
            DitoPushDebugLog.dump(event: .received, source: .app, userInfo: userInfo)

            self.notificationOffline.notificationRead(notificationRequest)
        }
    }

    /// - Parameter data: extra custom data for the click event. For an action
    ///   button tap it carries `action_id` / `action_label` (D-03).
    func notificationClick(
        notificationId: String,
        identifier: String,
        data: [String: String] = [:]
    ) {
        #if DEBUG
        let action = data[DitoRichPushKeys.actionId].map { " action=\($0)" } ?? ""
        DitoLogger.information("👆 [NOTIFICATION CLICK] id=\(notificationId)\(action)")
        #endif

        guard !notificationId.isEmpty else { return }

        Task {
            await processNotificationClick(
                notificationId: notificationId,
                identifier: identifier,
                data: data
            )
        }
    }

    private func processNotificationClick(
        notificationId: String,
        identifier: String,
        data: [String: String]
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
        do {
            try await client.activity(mapper.buildRequest(userId: identifier, activities: [activity]))
            DitoLogger.information("✅ [NOTIFICATION CLICK] Sucesso")
        } catch {
            DitoLogger.error(error.localizedDescription)
            // Keep the rich-push context so a replayed click still reports
            // which button was tapped.
            var customData = data
            let actionId = customData.removeValue(forKey: DitoRichPushKeys.actionId) ?? ""
            let actionLabel = customData.removeValue(forKey: DitoRichPushKeys.actionLabel) ?? ""
            let notificationData = DitoDataNotification(
                identifier: identifier,
                reference: "",
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
