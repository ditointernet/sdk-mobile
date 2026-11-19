import CoreData
import Foundation

class DitoRetry {

    static let maxRetries: Int16 = 5

    private var identifyOffline: DitoIdentifyOffline
    private var trackOffline: DitoTrackOffline
    private var notificationReadOffline: DitoNotificationOffline
    private let mapper = ActivityMapper()
    private let client: MobileIngestClientProtocol

    init(
        identifyOffline: DitoIdentifyOffline = .shared,
        trackOffline: DitoTrackOffline = .init(),
        notificationOffline: DitoNotificationOffline = .init(),
        client: MobileIngestClientProtocol? = nil
    ) {
        self.identifyOffline = identifyOffline
        self.trackOffline = trackOffline
        self.notificationReadOffline = notificationOffline
        self.client = client ?? MobileIngestClient.buildFromDitoConfig()
    }

    func loadOffline() {
        Task {
            await runLoadOffline()
        }
    }

    internal func runLoadOffline() async {
        await checkNotificationReceive()
        // Sequential so these requests don't each carry the anonymous Identify (a concurrent immediate send still may).
        await checkTrack(anonymous: true)
        await checkNotificationRegister(anonymous: true)
        await checkNotificationUnregister(anonymous: true)
        let identifySuccess = await checkIdentify()
        if identifySuccess {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.checkTrack(anonymous: false) }
                group.addTask { await self.checkNotification() }
                group.addTask { await self.checkNotificationRegister(anonymous: false) }
                group.addTask { await self.checkNotificationUnregister(anonymous: false) }
            }
        }
    }

    private func send(_ activities: [Mobileingest_V1_Activity], anonymous: Bool, userId: String) async throws {
        if anonymous {
            try await client.sendAnonymous(
                activities,
                mapper: mapper,
                allowIdentify: identifyOffline.identityState == .anonymous
            )
        } else {
            try await client.activity(mapper.buildRequest(userId: userId, activities: activities))
        }
    }

    private func ownerId(anonymous: Bool, reference: String?) -> String? {
        if anonymous { return "" }
        guard let reference, !reference.isEmpty else { return nil }
        return reference
    }

    private func checkIdentify() async -> Bool {
        guard let identify = identifyOffline.getIdentify,
              let id = identify.id,
              let signupRequest = identify.json?.convertToObject(type: DitoSignupRequest.self)
        else {
            return true
        }

        guard !identify.send else { return true }

        #if DEBUG
        DitoLogger.debug("🔄 [RETRY] Reenviando identify offline para id=\(id)")
        #endif

        let activity = mapper.mapFromDitoUser(userData: signupRequest.userData, userId: id)
        let request = mapper.buildRequest(userId: id, activities: [activity])
        do {
            try await client.activity(request)
            identifyOffline.update(id: id, params: signupRequest, reference: id, send: true)
            DitoLogger.information("✅ [RETRY] Identify enviado")
            DitoNotification(client: client).registerLastToken()
            return true
        } catch {
            DitoLogger.error(error.localizedDescription)
            return false
        }
    }

    private func checkTrack(anonymous: Bool) async {
        let tracks = trackOffline.offlinePersistedTracks.filter { $0.anonymous == anonymous }

        #if DEBUG
        if !tracks.isEmpty {
            DitoLogger.debug("🔄 [RETRY] Verificando \(tracks.count) evento(s) offline para reenvio")
        }
        #endif

        guard !tracks.isEmpty else { return }
        guard let userId = ownerId(anonymous: anonymous, reference: trackOffline.reference) else {
            DitoLogger.warning("Track - Antes de enviar um evento é preciso identificar o usuário.")
            return
        }

        var trackBatch: [(id: NSManagedObjectID, request: DitoEventRequest, retry: Int16)] = []
        trackBatch.reserveCapacity(tracks.count)

        for track in tracks {
            guard let eventJSON = track.event,
                  let eventRequest = eventJSON.convertToObject(type: DitoEventRequest.self)
            else {
                DitoLogger.error("Falha ao decodificar DitoEventRequest do JSON salvo")
                continue
            }

            let trackId = track.objectID
            let currentRetry = track.retry

            if currentRetry >= DitoRetry.maxRetries {
                trackOffline.delete(id: trackId)
                DitoLogger.warning("⚠️ [RETRY] Track descartado após \(DitoRetry.maxRetries) tentativas: \(eventRequest.event.action ?? "")")
                continue
            }

            #if DEBUG
            DitoLogger.debug("🔄 [RETRY] Reenviando evento: \(eventRequest.event.action ?? "") (tentativa \(currentRetry + 1))")
            #endif

            trackBatch.append((id: trackId, request: eventRequest, retry: currentRetry))
        }

        guard !trackBatch.isEmpty else { return }

        let activities = trackBatch.map { mapper.mapFromEventRequest($0.request) }
        do {
            try await send(activities, anonymous: anonymous, userId: userId)
            for item in trackBatch {
                trackOffline.delete(id: item.id)
            }
            if trackBatch.count == 1 {
                DitoLogger.information("✅ [RETRY] Track enviado")
            } else {
                DitoLogger.information("✅ [RETRY] \(trackBatch.count) tracks enviados")
            }
        } catch {
            for item in trackBatch {
                trackOffline.update(id: item.id, event: item.request, retry: item.retry + 1)
            }
            DitoLogger.error(error.localizedDescription)
        }
    }

    private func checkNotificationReceive() async {
        let pendingRows = notificationReadOffline.getNotificationReceive

        #if DEBUG
        if !pendingRows.isEmpty {
            DitoLogger.debug(
                "🔄 [RETRY] Verificando \(pendingRows.count) receive-ios-notification offline para reenvio"
            )
        }
        #endif

        for row in pendingRows {
            let rowId = row.id
            let rowRetry = row.retry
            guard let jsonData = row.json,
                  let pending = jsonData.convertToObject(type: DitoNotificationReceivePending.self)
            else { continue }

            if rowRetry >= DitoRetry.maxRetries {
                notificationReadOffline.deleteReceive(id: rowId)
                DitoLogger.warning(
                    "⚠️ [RETRY] receive-ios-notification descartado após \(DitoRetry.maxRetries) tentativas"
                )
                continue
            }

            let received = DitoNotificationReceived(with: [
                "notification": pending.notification,
                "log_id": pending.logId,
                "notification_name": pending.notificationName,
                "user_id": pending.userId,
            ])
            let identifyActivity = mapper.mapFromDitoUser(userData: DitoUser(), userId: pending.userId)
            let trackActivity = mapper.mapFromDitoEvent(
                Dito.createNotificationTrackEvent(received, token: pending.token)
            )
            let request = mapper.buildRequest(
                userId: pending.userId,
                activities: [identifyActivity, trackActivity]
            )

            do {
                #if DEBUG
                let ingestClient: MobileIngestClientProtocol =
                    Dito.testNotificationReceivedIngestClient ?? client
                #else
                let ingestClient: MobileIngestClientProtocol = client
                #endif
                try await ingestClient.activity(request)
                notificationReadOffline.deleteReceive(id: rowId)
                DitoNotificationReceiveTracker.markDelivered(
                    notification: pending.notification,
                    logId: pending.logId
                )
                DitoLogger.information("✅ [RETRY] receive-ios-notification enviado")
            } catch {
                notificationReadOffline.updateReceive(id: rowId, retry: rowRetry + 1)
                DitoLogger.error(error.localizedDescription)
            }
        }
    }

    private func checkNotification() async {
        let notifications = notificationReadOffline.getNotificationRead

        #if DEBUG
        if !notifications.isEmpty {
            DitoLogger.debug("🔄 [RETRY] Verificando \(notifications.count) notificação(ões) read offline para reenvio")
        }
        #endif

        guard let userId = notificationReadOffline.reference, !userId.isEmpty else {
            DitoLogger.warning("Notification Read - Antes de informar uma notificação lida é preciso identificar o usuário.")
            return
        }

        for notification in notifications {
            let notifID = notification.id
            let notifRetry = notification.retry
            guard let jsonData = notification.json,
                  let notificationRequest = jsonData.convertToObject(type: DitoNotificationOpenRequest.self)
            else { continue }

            if notifRetry >= DitoRetry.maxRetries {
                notificationReadOffline.deleteRead(id: notifID)
                DitoLogger.warning("⚠️ [RETRY] Notification Read descartada após \(DitoRetry.maxRetries) tentativas")
                continue
            }

            #if DEBUG
            DitoLogger.debug("🔄 [RETRY] Reenviando notification read: \(notificationRequest.data.notification) (tentativa \(notifRetry + 1))")
            #endif

            let activity = mapper.mapFromNotificationOpen(notificationRequest)
            let request = mapper.buildRequest(userId: userId, activities: [activity])
            do {
                try await client.activity(request)
                notificationReadOffline.deleteRead(id: notifID)
                DitoLogger.information("✅ [RETRY] Notification Read enviada")
            } catch {
                notificationReadOffline.updateRead(id: notifID, retry: notifRetry + 1)
                DitoLogger.error(error.localizedDescription)
            }
        }
    }

    private func checkNotificationRegister(anonymous: Bool) async {
        guard let notificationRegister = notificationReadOffline.getNotificationRegister,
              (notificationRegister.anonymous == true) == anonymous
        else { return }
        guard let userId = ownerId(anonymous: anonymous, reference: notificationReadOffline.reference) else {
            DitoLogger.warning("Register Token - Antes de registrar o token é preciso identificar o usuário.")
            return
        }
        guard let registerJson = notificationRegister.json,
              let registerRequest = registerJson.convertToObject(type: DitoTokenRequest.self)
        else { return }

        // The identify confirmation re-sends the last token with the user (`registerLastToken`).
        if anonymous, registerRequest.token == UserDefaults.lastPushToken {
            switch identifyOffline.identityState {
            case .identified:
                notificationReadOffline.deleteRegister(ifMatching: notificationRegister)
                return
            case .pending:
                return
            case .anonymous:
                break
            }
        }

        if notificationRegister.retry >= DitoRetry.maxRetries {
            notificationReadOffline.deleteRegister(ifMatching: notificationRegister)
            DitoLogger.warning("⚠️ [RETRY] Register token descartado após \(DitoRetry.maxRetries) tentativas")
            return
        }

        #if DEBUG
        DitoLogger.debug("🔄 [RETRY] Reenviando register token offline (tentativa \(notificationRegister.retry + 1))")
        #endif

        let activity = mapper.mapFromTokenRequest(registerRequest, isRegister: true)
        do {
            try await send([activity], anonymous: anonymous, userId: userId)
            notificationReadOffline.deleteRegister(ifMatching: notificationRegister)
            DitoLogger.information("✅ [RETRY] Token registrado")
        } catch {
            notificationReadOffline.updateRegister(id: nil, retry: notificationRegister.retry + 1)
            DitoLogger.error(error.localizedDescription)
        }
    }

    private func checkNotificationUnregister(anonymous: Bool) async {
        guard let notificationUnregister = notificationReadOffline.getNotificationUnregister,
              notificationUnregister.anonymous == anonymous
        else { return }
        guard let userId = ownerId(anonymous: anonymous, reference: notificationReadOffline.reference) else {
            DitoLogger.warning("Unregister Token - Antes de remover o token é preciso identificar o usuário.")
            return
        }
        guard let unregisterJson = notificationUnregister.json,
              let unregisterRequest = unregisterJson.convertToObject(type: DitoTokenRequest.self)
        else { return }

        if notificationUnregister.retry >= DitoRetry.maxRetries {
            notificationReadOffline.deleteUnregister()
            DitoLogger.warning("⚠️ [RETRY] Unregister token descartado após \(DitoRetry.maxRetries) tentativas")
            return
        }

        #if DEBUG
        DitoLogger.debug("🔄 [RETRY] Reenviando unregister token offline (tentativa \(notificationUnregister.retry + 1))")
        #endif

        let activity = mapper.mapFromTokenRequest(unregisterRequest, isRegister: false)
        do {
            try await send([activity], anonymous: anonymous, userId: userId)
            notificationReadOffline.deleteUnregister()
            DitoLogger.information("✅ [RETRY] Token removido")
        } catch {
            notificationReadOffline.updateUnregister(id: notificationUnregister.id, retry: notificationUnregister.retry + 1)
            DitoLogger.error(error.localizedDescription)
        }
    }
}
