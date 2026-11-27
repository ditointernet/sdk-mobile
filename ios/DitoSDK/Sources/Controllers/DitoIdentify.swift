import Foundation

class DitoIdentify {

    private let identifyOffline: DitoIdentifyOffline
    private let retry: DitoRetry
    private let mapper = ActivityMapper()
    private let client: MobileIngestClientProtocol

    init(
        identifyOffline: DitoIdentifyOffline = .shared,
        retry: DitoRetry = .init(),
        client: MobileIngestClientProtocol? = nil
    ) {
        self.identifyOffline = identifyOffline
        self.retry = retry
        self.client = client ?? MobileIngestClient.buildFromDitoConfig()
    }

    func identify(
        id: String,
        data: DitoUser? = nil,
        completion: ((Result<DitoOperationStatus, Error>) -> Void)? = nil
    ) {
        #if DEBUG
        DitoLogger.information("🆔 [IDENTIFY] user_id=\(id), email=\(data?.email ?? "nil")")
        #endif

        identifyOffline.initiateIdentify()

        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            identifyOffline.finishIdentify()
            completion?(.failure(DitoOperationError.invalidIdentifier))
            return
        }

        Task {
            await performIdentify(id: id, userData: data, completion: completion)
        }
    }

    private func performIdentify(
        id: String,
        userData: DitoUser?,
        completion: ((Result<DitoOperationStatus, Error>) -> Void)?
    ) async {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            identifyOffline.finishIdentify()
            completion?(.failure(DitoOperationError.invalidIdentifier))
            return
        }
        let activity = mapper.mapFromDitoUser(userData: userData, userId: id)
        let signupRequest = DitoSignupRequest(
            platformAppKey: Dito.appKey.isEmpty ? Dito.apiKey : Dito.appKey,
            sha1Signature: Dito.signature,
            userData: userData
        )
        do {
            try await client.activity(mapper.buildRequest(userId: id, activities: [activity]))
            identifyOffline.identify(id: id, params: signupRequest, reference: id, send: true)
            identifyOffline.finishIdentify()

            #if DEBUG
            DitoLogger.information("✅ [IDENTIFY] Sucesso")
            #endif

            completion?(.success(.sent))
            DitoNotification(client: client).registerLastToken()
            DitoRetry.endFailureBackoff()
            retry.loadOffline()
        } catch {
            // Without a device_id nothing was sent: the same user, already confirmed, stays identified until the
            // retry re-sends this identify.
            let keepsUser = error is DeviceIdUnavailableError && identifyOffline.getIdentify?.reference == id
            identifyOffline.identify(id: id, params: signupRequest, reference: keepsUser ? id : nil, send: false)
            identifyOffline.finishIdentify()
            DitoLogger.error(error.localizedDescription)
            completion?(keepsUser ? .success(.savedLocally) : .failure(error))
        }
    }
}
