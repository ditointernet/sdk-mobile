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

    func identify(id: String, data: DitoUser? = nil) {
        #if DEBUG
        DitoLogger.information("🆔 [IDENTIFY] user_id=\(id), email=\(data?.email ?? "nil")")
        #endif

        identifyOffline.initiateIdentify()

        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            identifyOffline.finishIdentify()
            return
        }

        Task {
            await performIdentify(id: id, userData: data)
        }
    }

    private func performIdentify(id: String, userData: DitoUser?) async {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            identifyOffline.finishIdentify()
            return
        }
        let activity = mapper.mapFromDitoUser(userData: userData, userId: id)
        let request = mapper.buildRequest(userId: id, activities: [activity])
        let signupRequest = DitoSignupRequest(
            platformAppKey: Dito.appKey.isEmpty ? Dito.apiKey : Dito.appKey,
            sha1Signature: Dito.signature,
            userData: userData
        )
        do {
            try await client.activity(request)
            identifyOffline.identify(id: id, params: signupRequest, reference: id, send: true)
            identifyOffline.finishIdentify()

            #if DEBUG
            DitoLogger.information("✅ [IDENTIFY] Sucesso")
            #endif

            retry.loadOffline()
        } catch {
            identifyOffline.identify(id: id, params: signupRequest, reference: nil, send: false)
            identifyOffline.finishIdentify()
            DitoLogger.error(error.localizedDescription)
        }
    }
}
