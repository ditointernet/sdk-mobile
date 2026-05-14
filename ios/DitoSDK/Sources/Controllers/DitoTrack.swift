import Foundation

class DitoTrack {

    private let trackOffline: DitoTrackOffline
    private let mapper = ActivityMapper()
    private let client: MobileIngestClientProtocol

    init(
        trackOffline: DitoTrackOffline = .init(),
        client: MobileIngestClientProtocol? = nil
    ) {
        self.trackOffline = trackOffline
        self.client = client ?? MobileIngestClient.buildFromDitoConfig()
    }

    func track(
        data: DitoEvent,
        completion: ((Result<DitoOperationStatus, Error>) -> Void)? = nil
    ) {
        #if DEBUG
        DitoLogger.information("📊 [TRACK] action=\(data.action ?? "nil")")
        #endif

        if trackOffline.checkIdentifyState() {
            trackOffline.setTrackCompletion {
                self.completeTracking(data: data, completion: completion)
            }
        } else {
            DispatchQueue.main.async {
                self.completeTracking(data: data, completion: completion)
            }
        }
    }

    private func completeTracking(
        data: DitoEvent,
        completion: ((Result<DitoOperationStatus, Error>) -> Void)?
    ) {
        DispatchQueue.global().async {
            guard let userId = self.trackOffline.reference, !userId.isEmpty else {
                let eventRequest = DitoEventRequest(
                    platformAppKey: Dito.appKey.isEmpty ? Dito.apiKey : Dito.appKey,
                    sha1Signature: Dito.signature,
                    event: data
                )
                self.trackOffline.track(event: eventRequest)
                DitoLogger.warning("⚠️ [TRACK] Usuário não identificado - salvando evento offline")
                completion?(.success(.savedLocally))
                return
            }
            self.performTracking(userId: userId, data: data, completion: completion)
        }
    }

    private func performTracking(
        userId: String,
        data: DitoEvent,
        completion: ((Result<DitoOperationStatus, Error>) -> Void)?
    ) {
        Task {
            let activity = mapper.mapFromDitoEvent(data)
            let request = mapper.buildRequest(userId: userId, activities: [activity])
            do {
                try await client.activity(request)
                DitoLogger.information("✅ [TRACK] Sucesso")
                completion?(.success(.sent))
            } catch {
                let eventRequest = DitoEventRequest(
                    platformAppKey: Dito.appKey.isEmpty ? Dito.apiKey : Dito.appKey,
                    sha1Signature: Dito.signature,
                    event: data
                )
                trackOffline.track(event: eventRequest)
                DitoLogger.error(error.localizedDescription)
                completion?(.success(.savedLocally))
            }
        }
    }
}
