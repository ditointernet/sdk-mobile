import CoreData
import Foundation

class DitoRetry {

    private enum Owner {
        case anonymous
        case user(String)
    }

    static let maxRetries: Int16 = 5

    private static let passLock = NSLock()
    private static var passRunning = false
    private static var nextPassRetry: DitoRetry?
    private static var nextPassIgnoresBackoff = false
    // Uptime, not wall clock: a clock set back would stretch the backoff.
    private static var lastFailureAt: TimeInterval?
    private static var passFailures = 0
    private static var scheduledPass: DispatchWorkItem?
    private static var scheduledPassGeneration = 0
    private static var passEpoch = 0
    static let failureBackoff: TimeInterval = 60
    #if DEBUG
    static var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    static var schedulePass: (TimeInterval, DispatchWorkItem) -> Void = DitoRetry.defaultSchedulePass
    static var isOnline: () -> Bool = { Dito.isOnline }
    #else
    private static let isOnline: () -> Bool = { Dito.isOnline }
    private static let now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    private static let schedulePass: (TimeInterval, DispatchWorkItem) -> Void = DitoRetry.defaultSchedulePass
    #endif

    private static func defaultSchedulePass(_ delay: TimeInterval, _ work: DispatchWorkItem) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

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

    // One pass at a time across instances so no row goes twice; a call mid-pass queues one more pass.
    // `ignoringBackoff`: a network change, so an earlier failure says nothing about this pass.
    func loadOffline(ignoringBackoff: Bool = false) {
        guard let epoch = DitoRetry.startOrQueuePass(self, ignoringBackoff: ignoringBackoff) else { return }
        Task {
            var next: DitoRetry? = self
            while let retry = next {
                await retry.runLoadOffline()
                next = DitoRetry.finishPass(epoch: epoch)
            }
        }
    }

    // After a failed send, passes wait out the backoff (each failed pass spends a retry of every row);
    // a skipped pass is run once when the backoff ends.
    // A call mid-pass is queued even in the backoff: the end of the pass decides whether it waits.
    private static func startOrQueuePass(_ retry: DitoRetry, ignoringBackoff: Bool) -> Int? {
        passLock.lock()
        defer { passLock.unlock() }
        if passRunning {
            nextPassRetry = retry
            nextPassIgnoresBackoff = nextPassIgnoresBackoff || ignoringBackoff
            return nil
        }
        if !ignoringBackoff, inFailureBackoff() {
            DitoLogger.warning("⚠️ [RETRY] Passada adiada: houve falha de envio há menos de \(Int(failureBackoff))s")
            schedulePassAfterBackoff(retry)
            return nil
        }
        passRunning = true
        passFailures = 0
        return passEpoch
    }

    private static func finishPass(epoch: Int) -> DitoRetry? {
        passLock.lock()
        defer { passLock.unlock() }
        guard epoch == passEpoch else { return nil }
        if passFailures == 0 {
            lastFailureAt = nil
            clearScheduledPass()
        }
        var next = nextPassRetry
        if let queued = next, !nextPassIgnoresBackoff, inFailureBackoff() {
            schedulePassAfterBackoff(queued)
            next = nil
        }
        nextPassRetry = nil
        nextPassIgnoresBackoff = false
        passRunning = next != nil
        passFailures = 0
        return next
    }

    /// Call with `passLock` held.
    private static func schedulePassAfterBackoff(_ retry: DitoRetry) {
        guard scheduledPass == nil, let failedAt = lastFailureAt else { return }
        scheduledPassGeneration += 1
        let generation = scheduledPassGeneration
        let work = DispatchWorkItem {
            DitoRetry.passLock.lock()
            let isCurrent = DitoRetry.scheduledPassGeneration == generation
            if isCurrent {
                DitoRetry.scheduledPass = nil
            }
            DitoRetry.passLock.unlock()
            // Offline it would only spend a retry per row; the reconnection runs a pass instead.
            if isCurrent, DitoRetry.isOnline() {
                retry.loadOffline()
            }
        }
        scheduledPass = work
        schedulePass(failureBackoff - (now() - failedAt), work)
    }

    /// Call with `passLock` held.
    private static func clearScheduledPass() {
        scheduledPass?.cancel()
        scheduledPass = nil
        scheduledPassGeneration += 1
    }

    static func cancelScheduledPass() {
        passLock.lock()
        defer { passLock.unlock() }
        clearScheduledPass()
    }

    /// A live send went through: the backend is up, so the queue need not wait out the backoff.
    static func endFailureBackoff() {
        passLock.lock()
        defer { passLock.unlock() }
        lastFailureAt = nil
        clearScheduledPass()
    }

    /// Call with `passLock` held.
    private static func inFailureBackoff() -> Bool {
        guard let failedAt = lastFailureAt else { return false }
        return now() - failedAt < failureBackoff
    }

    private static func recordFailure() {
        passLock.lock()
        defer { passLock.unlock() }
        lastFailureAt = now()
        passFailures += 1
    }

    #if DEBUG
    static func resetForTests() {
        passLock.lock()
        defer { passLock.unlock() }
        passEpoch += 1
        passRunning = false
        nextPassRetry = nil
        nextPassIgnoresBackoff = false
        lastFailureAt = nil
        passFailures = 0
        clearScheduledPass()
        now = { ProcessInfo.processInfo.systemUptime }
        schedulePass = defaultSchedulePass
        isOnline = { Dito.isOnline }
    }
    #endif

    internal func runLoadOffline() async {
        guard !DeviceIdProvider.get().isEmpty else {
            DitoLogger.error("❌ [RETRY] device_id indisponível (falha ao ler o Keychain): fila offline mantida, nada enviado")
            return
        }
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

    private func send(_ activities: [Mobileingest_V1_Activity], owner: Owner) async throws {
        switch owner {
        case .anonymous:
            try await client.sendAnonymous(activities, mapper: mapper)
        case .user(let userId):
            try await client.activity(mapper.buildRequest(userId: userId, activities: activities))
        }
    }

    /// nil means wait: no user yet, or for an anonymous row an identify pending or in progress.
    private func owner(anonymous: Bool, reference: String?) -> Owner? {
        if anonymous {
            guard identifyOffline.identityState != .pending else { return nil }
            return .anonymous
        }
        guard let reference, !reference.isEmpty else { return nil }
        return .user(reference)
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
        do {
            try await client.activity(mapper.buildRequest(userId: id, activities: [activity]))
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
        let tracks = trackOffline.persistedTracks(anonymous: anonymous)
        #if DEBUG
        if !tracks.isEmpty {
            DitoLogger.debug("🔄 [RETRY] Verificando \(tracks.count) evento(s) offline para reenvio")
        }
        #endif

        guard !tracks.isEmpty else { return }
        guard let owner = self.owner(anonymous: anonymous, reference: trackOffline.reference) else {
            DitoLogger.warning(anonymous
                ? "Track - Identify pendente; eventos anônimos aguardam a conclusão."
                : "Track - Antes de enviar um evento é preciso identificar o usuário.")
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
            try await send(activities, owner: owner)
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
            DitoRetry.recordFailure()
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
            // Arrival time, not resend time; a row from before receivedAt existed falls back to now.
            var receiveEvent = Dito.createNotificationTrackEvent(received, token: pending.token)
            receiveEvent.createdAt = pending.receivedAt
            let trackActivity = mapper.mapFromDitoEvent(receiveEvent)

            do {
                #if DEBUG
                let ingestClient: MobileIngestClientProtocol =
                    Dito.testNotificationReceivedIngestClient ?? client
                #else
                let ingestClient: MobileIngestClientProtocol = client
                #endif
                try await ingestClient.activity(mapper.buildRequest(
                    userId: pending.userId,
                    activities: [identifyActivity, trackActivity]
                ))
                notificationReadOffline.deleteReceive(id: rowId)
                DitoNotificationReceiveTracker.markDelivered(
                    notification: pending.notification,
                    logId: pending.logId
                )
                DitoLogger.information("✅ [RETRY] receive-ios-notification enviado")
            } catch {
                notificationReadOffline.updateReceive(id: rowId, retry: rowRetry + 1)
                DitoRetry.recordFailure()
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
            do {
                try await client.activity(mapper.buildRequest(userId: userId, activities: [activity]))
                notificationReadOffline.deleteRead(id: notifID)
                DitoLogger.information("✅ [RETRY] Notification Read enviada")
            } catch {
                notificationReadOffline.updateRead(id: notifID, retry: notifRetry + 1)
                DitoRetry.recordFailure()
                DitoLogger.error(error.localizedDescription)
            }
        }
    }

    private func checkNotificationRegister(anonymous: Bool) async {
        guard let notificationRegister = notificationReadOffline.getNotificationRegister,
              (notificationRegister.anonymous == true) == anonymous
        else { return }
        guard let registerJson = notificationRegister.json,
              let registerRequest = registerJson.convertToObject(type: DitoTokenRequest.self)
        else { return }

        let lastToken = UserDefaults.lastPushToken
        // nil: a register queued by an SDK version that didn't record the last token; it is still sent.
        if let lastToken, registerRequest.token != lastToken {
            notificationReadOffline.deleteRegister(ifMatching: notificationRegister)
            DitoLogger.warning("⚠️ [RETRY] Register de token que não é mais o atual descartado sem envio")
            return
        }
        // The identify confirmation re-sends the last token with the user (`registerLastToken`).
        if anonymous, registerRequest.token == lastToken {
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
        guard let owner = self.owner(anonymous: anonymous, reference: notificationReadOffline.reference) else {
            DitoLogger.warning(anonymous
                ? "Register Token - Identify pendente; token anônimo aguarda a conclusão."
                : "Register Token - Antes de registrar o token é preciso identificar o usuário.")
            return
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
            try await send([activity], owner: owner)
            notificationReadOffline.deleteRegister(ifMatching: notificationRegister)
            if case .user(let userId) = owner, identifyOffline.identityState == .identified(userId),
               UserDefaults.lastPushToken == registerRequest.token {
                UserDefaults.lastUserTokenRegister = ["user_id": userId, "token": registerRequest.token]
            }
            DitoLogger.information("✅ [RETRY] Token registrado")
        } catch {
            notificationReadOffline.updateRegister(ifMatching: notificationRegister, retry: notificationRegister.retry + 1)
            DitoRetry.recordFailure()
            DitoLogger.error(error.localizedDescription)
        }
    }

    private func checkNotificationUnregister(anonymous: Bool) async {
        guard let notificationUnregister = notificationReadOffline.getNotificationUnregister,
              notificationUnregister.anonymous == anonymous
        else { return }
        guard let owner = self.owner(anonymous: anonymous, reference: notificationReadOffline.reference) else {
            DitoLogger.warning(anonymous
                ? "Unregister Token - Identify pendente; remoção anônima aguarda a conclusão."
                : "Unregister Token - Antes de remover o token é preciso identificar o usuário.")
            return
        }
        guard let unregisterJson = notificationUnregister.json,
              let unregisterRequest = unregisterJson.convertToObject(type: DitoTokenRequest.self)
        else { return }

        if notificationUnregister.retry >= DitoRetry.maxRetries {
            notificationReadOffline.deleteUnregister(id: notificationUnregister.id)
            DitoLogger.warning("⚠️ [RETRY] Unregister token descartado após \(DitoRetry.maxRetries) tentativas")
            return
        }

        #if DEBUG
        DitoLogger.debug("🔄 [RETRY] Reenviando unregister token offline (tentativa \(notificationUnregister.retry + 1))")
        #endif

        let activity = mapper.mapFromTokenRequest(unregisterRequest, isRegister: false)
        do {
            try await send([activity], owner: owner)
            notificationReadOffline.deleteUnregister(id: notificationUnregister.id)
            DitoLogger.information("✅ [RETRY] Token removido")
        } catch {
            notificationReadOffline.updateUnregister(id: notificationUnregister.id, retry: notificationUnregister.retry + 1)
            DitoRetry.recordFailure()
            DitoLogger.error(error.localizedDescription)
        }
    }
}
