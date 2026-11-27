import Foundation

class DitoTrack {

    private let trackOffline: DitoTrackOffline
    private let mapper = ActivityMapper()
    private let client: MobileIngestClientProtocol
    private let onSent: () -> Void

    init(
        trackOffline: DitoTrackOffline = .init(),
        client: MobileIngestClientProtocol? = nil,
        onSent: @escaping () -> Void = Dito.flushOfflineQueue
    ) {
        self.trackOffline = trackOffline
        self.client = client ?? MobileIngestClient.buildFromDitoConfig()
        self.onSent = onSent
    }

    func track(
        data: DitoEvent,
        completion: ((Result<DitoOperationStatus, Error>) -> Void)? = nil
    ) {
        #if DEBUG
        DitoLogger.information("📊 [TRACK] action=\(data.action ?? "nil")")
        #endif

        var stamped = data
        if stamped.createdAt == nil {
            stamped.createdAt = Date().formatToISO
        }
        let event = stamped

        if trackOffline.checkIdentifyState() {
            trackOffline.setTrackCompletion {
                self.completeTracking(data: event, completion: completion)
            }
        } else {
            DispatchQueue.main.async {
                self.completeTracking(data: event, completion: completion)
            }
        }
    }

    private func completeTracking(
        data: DitoEvent,
        completion: ((Result<DitoOperationStatus, Error>) -> Void)?
    ) {
        DispatchQueue.global().async {
            switch self.trackOffline.identityState {
            case .identified(let reference):
                self.performTracking(userId: reference, data: data, completion: completion)
            case .anonymous:
                self.performTracking(userId: nil, data: data, completion: completion)
            case .pending:
                self.trackOffline.track(event: self.makeEventRequest(data))
                DitoLogger.warning("⚠️ [TRACK] Usuário não identificado - salvando evento offline")
                completion?(.success(.savedLocally))
            }
        }
    }

    private func performTracking(
        userId: String?,
        data: DitoEvent,
        completion: ((Result<DitoOperationStatus, Error>) -> Void)?
    ) {
        Task {
            let activity = mapper.mapFromDitoEvent(data)
            do {
                if let userId {
                    try await client.activity(mapper.buildRequest(userId: userId, activities: [activity]))
                } else {
                    try await client.sendAnonymous([activity], mapper: mapper)
                }
                DitoLogger.information("✅ [TRACK] Sucesso")
                completion?(.success(.sent))
                DitoRetry.endFailureBackoff()
                onSent()
            } catch {
                trackOffline.track(event: makeEventRequest(data), anonymous: userId == nil)
                DitoLogger.error(error.localizedDescription)
                completion?(.success(.savedLocally))
            }
        }
    }

    private func makeEventRequest(_ data: DitoEvent) -> DitoEventRequest {
        DitoEventRequest(
            platformAppKey: Dito.appKey.isEmpty ? Dito.apiKey : Dito.appKey,
            sha1Signature: Dito.signature,
            event: data
        )
    }
}
