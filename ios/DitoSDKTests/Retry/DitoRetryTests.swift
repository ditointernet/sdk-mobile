import Security
import XCTest
@testable import DitoSDK

final class DitoRetryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestHelpers.resetAllState()
        Dito.appKey = "unit-test-app-key"
        Dito.appSecret = ""
        Dito.signature = "unit-test-signature"
        Dito.apiKey = ""
        Dito.bundleId = "br.com.dito.sdk.unit.tests"
        _ = DitoCoreDataManager.shared.persistentContainer
    }

    override func tearDown() {
        TestHelpers.resetAllState()
        Dito.appKey = ""
        Dito.appSecret = ""
        Dito.signature = ""
        Dito.apiKey = ""
        Dito.bundleId = ""
        super.tearDown()
    }

    private func waitForTrackRowsWithEvents(_ count: Int, timeout: TimeInterval = 10) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let rows = DitoTrackDataManager().fetchOfflinePersistedTracks()
            if rows.count >= count,
               rows.allSatisfy({ row in
                   guard let e = row.event, !e.isEmpty else { return false }
                   return true
               }) {
                return
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        let rows = DitoTrackDataManager().fetchOfflinePersistedTracks()
        XCTFail("timed out waiting for \(count) track rows with event; count=\(rows.count)")
    }

    private func makeSignup() -> DitoSignupRequest {
        DitoSignupRequest(
            platformAppKey: Dito.appKey.isEmpty ? Dito.apiKey : Dito.appKey,
            sha1Signature: Dito.signature,
            userData: DitoUser(email: "retry@example.com")
        )
    }

    private func makeTokenRequest(token: String) -> DitoTokenRequest {
        DitoTokenRequest(
            platformAppKey: Dito.appKey.isEmpty ? Dito.apiKey : Dito.appKey,
            sha1Signature: Dito.signature,
            token: token
        )
    }

    private func makeClickRequest(
        notificationId: String,
        userId: String,
        actionId: String = ""
    ) -> DitoNotificationOpenRequest {
        DitoNotificationOpenRequest(
            platformAppKey: Dito.appKey.isEmpty ? Dito.apiKey : Dito.appKey,
            sha1Signature: Dito.signature,
            data: DitoDataNotification(
                from: [
                    "user_id": userId,
                    "notification": notificationId,
                    "log_id": "log-\(notificationId)",
                    "notification_name": "campanha-clique",
                    "title": "titulo",
                    "message": "mensagem",
                ],
                actionId: actionId,
                actionLabel: actionId.isEmpty ? "" : "Ver oferta"
            )
        )
    }

    private func saveTrack(action: String, anonymous: Bool = false) {
        let request = DitoEventRequest(
            platformAppKey: Dito.appKey,
            sha1Signature: Dito.signature,
            event: DitoEvent(action: action, customData: nil)
        )
        XCTAssertTrue(DitoTrackDataManager().save(event: request.toString, anonymous: anonymous))
    }

    private func trackEvents(_ request: Mobileingest_V1_Request) -> [String] {
        request.activities.compactMap { activity in
            guard let oneOf = activity.activity, case .track(let track) = oneOf else { return nil }
            return track.event
        }
    }

    private func savePostIdentify(userId: String) {
        let signup = makeSignup()
        guard let signupJson = signup.toString else {
            XCTFail("signup json")
            return
        }
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: signupJson, send: true))
        XCTAssertEqual(DitoIdentifyOffline.shared.getIdentify?.send, true)
        XCTAssertEqual(DitoTrackOffline().reference, userId)
    }

    func testLoadOffline_postIdentify_pendingRegister_sendsTokenRegisterAndClearsUserDefaults() async throws {
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = true

        let userId = "uid-retry-token-register-1"
        let token = "fcm-register-pending-abc"
        savePostIdentify(userId: userId)

        let tokenRequest = makeTokenRequest(token: token)
        guard let registerJson = tokenRequest.toString else {
            XCTFail("token json")
            return
        }
        XCTAssertTrue(DitoNotificationRegisterDataManager().save(with: registerJson, retry: 0))
        XCTAssertNotNil(DitoNotificationRegisterDataManager().fetch?.json)

        let sut = DitoRetry(client: mock)
        await sut.runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1)
        let req = try XCTUnwrap(mock.allActivityRequests.first)
        XCTAssertEqual(req.userID, userId)
        XCTAssertEqual(req.activities.count, 1)
        let act = try XCTUnwrap(req.activities.first)
        guard let oneOf = act.activity, case .tokenRegister(let reg) = oneOf else {
            XCTFail("esperado tokenRegister; activity=\(String(describing: act.activity))")
            return
        }
        XCTAssertEqual(reg.token, token)
        XCTAssertEqual(reg.provider, .providerFcm)

        XCTAssertNil(DitoNotificationRegisterDataManager().fetch)
    }

    /// Se o ingest falha, a linha do unregister fica — e o contador **avança**.
    ///
    /// Sob o fault órfão o `guard` desistia ao ler `json` nil, sem tocar no `retry`:
    /// o token nunca era removido no backend e continuava recebendo push.
    func testLoadOffline_postIdentify_pendingUnregister_ingestFails_rowSurvivesWithIncrementedRetry() async throws {
        let mock = MockMobileIngestClient()

        let userId = "uid-retry-token-unregister-fail-1"
        savePostIdentify(userId: userId)

        let tokenRequest = makeTokenRequest(token: "fcm-unregister-fail-xyz")
        guard let unregisterJson = tokenRequest.toString else {
            XCTFail("token json")
            return
        }
        XCTAssertTrue(DitoNotificationUnregisterDataManager().save(with: unregisterJson, retry: 0))

        mock.shouldSucceed = false
        let sut = DitoRetry(client: mock)
        await sut.runLoadOffline()

        let row = try XCTUnwrap(
            DitoNotificationUnregisterDataManager().fetch,
            "o unregister não pode ser descartado por uma falha de rede"
        )
        XCTAssertEqual(row.retry, 1, "o contador tem de avançar, senão o token nunca é removido nem expira")
        XCTAssertNotNil(row.json)
    }

    func testLoadOffline_postIdentify_pendingUnregister_sendsTokenUnregisterAndClearsCoreData() async throws {
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = true

        let userId = "uid-retry-token-unregister-1"
        let token = "fcm-unregister-pending-xyz"
        savePostIdentify(userId: userId)

        let tokenRequest = makeTokenRequest(token: token)
        guard let unregisterJson = tokenRequest.toString else {
            XCTFail("token json")
            return
        }
        XCTAssertTrue(DitoNotificationUnregisterDataManager().save(with: unregisterJson, retry: 0))
        XCTAssertNotNil(DitoNotificationUnregisterDataManager().fetch)

        let sut = DitoRetry(client: mock)
        await sut.runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1)
        let req = try XCTUnwrap(mock.allActivityRequests.first)
        XCTAssertEqual(req.userID, userId)
        XCTAssertEqual(req.activities.count, 1)
        let act = try XCTUnwrap(req.activities.first)
        guard let oneOf = act.activity, case .tokenUnregister(let unreg) = oneOf else {
            XCTFail("esperado tokenUnregister; activity=\(String(describing: act.activity))")
            return
        }
        XCTAssertEqual(unreg.token, token)
        XCTAssertEqual(unreg.provider, .providerFcm)

        XCTAssertNil(DitoNotificationUnregisterDataManager().fetch)
    }

    /// O clique offline tem de chegar ao ingest com o payload inteiro.
    ///
    /// Cobre a regressão do fault órfão de CoreData: quando `fetchAll` devolvia o
    /// `NSManagedObject`, `json` voltava nil fora do contexto e este reenvio era
    /// silenciosamente pulado.
    func testLoadOffline_postIdentify_pendingClick_sendsPushClickWithPayloadAndClearsCoreData() async throws {
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = true

        let userId = "uid-retry-click-1"
        let notificationId = "01KYTJGZF2K8F2F4C84ZNE734J"
        savePostIdentify(userId: userId)

        let click = makeClickRequest(
            notificationId: notificationId,
            userId: userId,
            actionId: "btn-oferta"
        )
        guard let clickJson = click.toString else {
            XCTFail("click json")
            return
        }
        XCTAssertTrue(DitoNotificationReadDataManager().save(with: clickJson, retry: 0))

        let sut = DitoRetry(client: mock)
        await sut.runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1)
        let req = try XCTUnwrap(mock.allActivityRequests.first)
        XCTAssertEqual(req.userID, userId)
        XCTAssertEqual(req.activities.count, 1)
        let act = try XCTUnwrap(req.activities.first)
        guard let oneOf = act.activity, case .trackPushClick(let pushClick) = oneOf else {
            XCTFail("esperado trackPushClick; activity=\(String(describing: act.activity))")
            return
        }
        XCTAssertEqual(pushClick.notification.notificationID, notificationId)
        XCTAssertEqual(pushClick.notification.identifier, userId)
        XCTAssertEqual(
            pushClick.data[DitoRichPushKeys.actionId]?.single.stringValue,
            "btn-oferta",
            "o action_id do botão precisa sobreviver ao trânsito pelo offline"
        )

        XCTAssertTrue(DitoNotificationReadDataManager().fetchAll.isEmpty)
    }

    /// Se o ingest falha, a linha do clique fica — e o contador **avança**.
    ///
    /// Sob o fault órfão o `guard` pulava a linha antes de mexer no `retry`, então o
    /// clique nunca era reenviado nem descartado: ficava preso na fila para sempre.
    func testLoadOffline_postIdentify_pendingClick_ingestFails_rowSurvivesWithIncrementedRetry() async throws {
        let mock = MockMobileIngestClient()

        let userId = "uid-retry-click-fail-1"
        savePostIdentify(userId: userId)

        let click = makeClickRequest(notificationId: "notif-click-fail", userId: userId)
        guard let clickJson = click.toString else {
            XCTFail("click json")
            return
        }
        XCTAssertTrue(DitoNotificationReadDataManager().save(with: clickJson, retry: 0))

        mock.shouldSucceed = false
        let sut = DitoRetry(client: mock)
        await sut.runLoadOffline()

        let rows = DitoNotificationReadDataManager().fetchAll
        XCTAssertEqual(rows.count, 1, "a linha do clique não pode ser descartada por uma falha de rede")
        XCTAssertEqual(rows.first?.retry, 1, "o contador tem de avançar, senão o clique nunca sai nem expira")
        XCTAssertNotNil(rows.first?.json)
    }

    func testLoadOffline_postIdentify_pendingClick_resendsLogIdNameAndChannel() async throws {
        let mock = MockMobileIngestClient()
        let userId = "uid-retry-click-log"
        savePostIdentify(userId: userId)
        let clickJson = try XCTUnwrap(makeClickRequest(notificationId: "notif-click-log", userId: userId).toString)
        XCTAssertTrue(DitoNotificationReadDataManager().save(with: clickJson, retry: 0))

        await DitoRetry(client: mock).runLoadOffline()

        let act = try XCTUnwrap(mock.allActivityRequests.first?.activities.first)
        guard case .trackPushClick(let pushClick)? = act.activity else {
            return XCTFail("esperado trackPushClick; activity=\(String(describing: act.activity))")
        }
        XCTAssertEqual(pushClick.notification.dispatchID, "log-notif-click-log")
        XCTAssertEqual(pushClick.notification.name, "campanha-clique")
        XCTAssertEqual(pushClick.notification.channel, "mobile")
    }

    #if DEBUG
    func testLoadOffline_pendingReceive_isResentAsPushReceiptWithArrivalTime() async throws {
        let mock = MockMobileIngestClient()
        Dito.testNotificationReceivedIngestClient = mock
        addTeardownBlock { Dito.testNotificationReceivedIngestClient = nil }
        let arrival = Date(timeIntervalSince1970: 1_700_000_000)
        DitoNotificationOffline().notificationReceive(DitoNotificationReceivePending(
            userId: "uid-retry-receive",
            token: "fcm-retry-receive",
            notification: "notif-retry-receive",
            logId: "log-retry-receive",
            notificationName: "Campanha recebida",
            receivedAt: arrival.formatToISO
        ))

        await DitoRetry(client: mock).runLoadOffline()

        let req = try XCTUnwrap(mock.allActivityRequests.first)
        XCTAssertEqual(req.userID, "uid-retry-receive")
        XCTAssertEqual(req.activities.map(\.type), [.activityIdentify, .activityTrack])
        let act = req.activities[1]
        guard case .trackPushReceipt(let receipt)? = act.activity else {
            return XCTFail("esperado trackPushReceipt; activity=\(String(describing: act.activity))")
        }
        XCTAssertEqual(receipt.notification.notificationID, "notif-retry-receive")
        XCTAssertEqual(receipt.notification.dispatchID, "log-retry-receive")
        XCTAssertEqual(receipt.notification.name, "Campanha recebida")
        XCTAssertEqual(receipt.notification.identifier, "uid-retry-receive")
        XCTAssertEqual(receipt.notification.channel, "mobile")
        XCTAssertEqual(act.timestamp.date, arrival)
        XCTAssertTrue(DitoNotificationOffline().getNotificationReceive.isEmpty)
    }
    #endif

    func testLoadOffline_identifyNotSent_firstActivityFails_tracksRemainAndNoFurtherActivityCalls() async throws {
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = false

        let userId = "uid-retry-identify-fail-1"
        saveTrack(action: "retry_evt_fail_a")
        saveTrack(action: "retry_evt_fail_b")
        await waitForTrackRowsWithEvents(2)

        let signup = makeSignup()
        guard let signupJson = signup.toString else {
            XCTFail("signup json")
            return
        }
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: signupJson, send: false))
        XCTAssertEqual(DitoIdentifyOffline.shared.getIdentify?.send, false)
        XCTAssertEqual(DitoTrackOffline().offlinePersistedTracks.count, 2)

        let sut = DitoRetry(client: mock)
        await sut.runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1, "apenas a tentativa de identify deve chamar activity")
        let first = try XCTUnwrap(mock.allActivityRequests.first)
        XCTAssertEqual(first.userID, userId)
        XCTAssertEqual(first.activities.count, 1)
        XCTAssertEqual(first.activities.first?.type, .activityIdentify)

        XCTAssertEqual(DitoIdentifyOffline.shared.getIdentify?.send, false)
        XCTAssertEqual(DitoTrackOffline().offlinePersistedTracks.count, 2)
    }

    func testLoadOffline_identifyNotSent_succeeds_marksIdentifySentWithoutTracks() async throws {
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = true

        let userId = "uid-retry-identify-only-1"
        let signup = makeSignup()
        guard let signupJson = signup.toString else {
            XCTFail("signup json")
            return
        }
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: signupJson, send: false))

        let sut = DitoRetry(client: mock)
        await sut.runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1)
        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.activities.count, 1)
        XCTAssertEqual(req.activities.first?.type, .activityIdentify)
        XCTAssertEqual(DitoIdentifyOffline.shared.getIdentify?.send, true)
    }

    func testLoadOffline_identifySucceeds_thenPendingTracksAreSentInSingleActivityRequest() async throws {
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = true

        let userId = "uid-retry-identify-tracks-1"
        saveTrack(action: "retry_evt_ok_a")
        saveTrack(action: "retry_evt_ok_b")
        await waitForTrackRowsWithEvents(2)

        let signup = makeSignup()
        guard let signupJson = signup.toString else {
            XCTFail("signup json")
            return
        }
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: signupJson, send: false))
        XCTAssertEqual(DitoIdentifyOffline.shared.getIdentify?.send, false)

        let sut = DitoRetry(client: mock)
        await sut.runLoadOffline()

        XCTAssertEqual(DitoIdentifyOffline.shared.getIdentify?.send, true)
        XCTAssertTrue(DitoTrackOffline().offlinePersistedTracks.isEmpty)

        XCTAssertGreaterThanOrEqual(mock.activityCallCount, 2)
        let identifyReqs = mock.allActivityRequests.filter { $0.activities.contains { $0.type == .activityIdentify } }
        XCTAssertEqual(identifyReqs.count, 1)
        let identifyReq = try XCTUnwrap(identifyReqs.first)
        XCTAssertEqual(identifyReq.activities.filter { $0.type == .activityIdentify }.count, 1)

        guard let batchReq = mock.allActivityRequests.first(where: { req in
            let tracks = req.activities.filter { $0.type == .activityTrack }
            return tracks.count >= 2
        }) else {
            XCTFail(
                "esperado um pedido com batch de tracks; calls=\(mock.activityCallCount) sizes=\(mock.allActivityRequests.map { $0.activities.count }) types=\(mock.allActivityRequests.map { $0.activities.map(\.type) })"
            )
            return
        }
        XCTAssertEqual(batchReq.userID, userId)
        XCTAssertEqual(batchReq.activities.filter { $0.type == .activityTrack }.count, 2)
    }

    #if DEBUG
    func testAnonymousTrackFails_isQueuedAsAnonymous_andRetryWithoutIdentifySendsItAnonymously() async throws {
        DeviceIdProvider.setForTests("device-retry-anon-1")
        let failing = MockMobileIngestClient()
        failing.shouldSucceed = false

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DitoTrack(client: failing).track(data: DitoEvent(action: "anon_retry_evt", customData: nil)) { _ in
                cont.resume()
            }
        }
        await waitForTrackRowsWithEvents(1)

        XCTAssertEqual(failing.activityCallCount, 1)
        XCTAssertEqual(DitoTrackOffline().offlinePersistedTracks.first?.anonymous, true)
        XCTAssertNil(UserDefaults.anonymousIdentifyMark, "a falha não pode gravar a marca do Identify anônimo")

        let mock = MockMobileIngestClient()
        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1)
        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, "")
        XCTAssertEqual(req.activities.map(\.type), [.activityIdentify, .activityTrack])
        XCTAssertEqual(trackEvents(req), ["anon_retry_evt"])
        XCTAssertTrue(DitoTrackOffline().offlinePersistedTracks.isEmpty)
        XCTAssertNotNil(UserDefaults.anonymousIdentifyMark)
    }

    func testAnonymousTokenRows_retryWithoutIdentifySendsThemAnonymouslyAndClearsQueues() async throws {
        DeviceIdProvider.setForTests("device-retry-anon-token-1")
        let registerJson = try XCTUnwrap(makeTokenRequest(token: "fcm-anon-register").toString)
        let unregisterJson = try XCTUnwrap(makeTokenRequest(token: "fcm-anon-unregister").toString)
        XCTAssertTrue(DitoNotificationRegisterDataManager().save(with: registerJson, retry: 0, anonymous: true))
        XCTAssertTrue(DitoNotificationUnregisterDataManager().save(with: unregisterJson, retry: 0, anonymous: true))

        let mock = MockMobileIngestClient()
        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 2)
        XCTAssertTrue(mock.allActivityRequests.allSatisfy { $0.userID.isEmpty })
        XCTAssertEqual(mock.allActivityRequests.first?.activities.first?.type, .activityIdentify)
        XCTAssertEqual(mock.allActivityRequests.last?.activities.count, 1, "só a primeira chamada anônima leva o Identify")
        XCTAssertNil(DitoNotificationRegisterDataManager().fetch)
        XCTAssertNil(DitoNotificationUnregisterDataManager().fetch)
    }

    func testAnonymousRows_withoutDeviceId_sendNothingAndKeepQueueAndRetry() async throws {
        DeviceIdProvider.copyMatching = { _, _ in errSecInteractionNotAllowed }
        saveTrack(action: "anon_no_device_evt", anonymous: true)
        XCTAssertTrue(DitoNotificationRegisterDataManager().save(
            with: makeTokenRequest(token: "fcm-no-device-register").toString,
            retry: 0,
            anonymous: true
        ))
        XCTAssertTrue(DitoNotificationUnregisterDataManager().save(
            with: makeTokenRequest(token: "fcm-no-device-unregister").toString,
            retry: 0,
            anonymous: true
        ))
        await waitForTrackRowsWithEvents(1)
        let mock = MockMobileIngestClient()

        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 0)
        let tracks = DitoTrackOffline().offlinePersistedTracks
        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks.first?.retry, 1)
        XCTAssertEqual(DitoNotificationRegisterDataManager().fetch?.retry, 0)
        XCTAssertEqual(DitoNotificationUnregisterDataManager().fetch?.retry, 0)
    }

    func testPendingIdentify_anonymousTrackInQueue_isNotSentAndKeepsRetry() async throws {
        DeviceIdProvider.setForTests("device-retry-pending-anon-track-1")
        saveTrack(action: "pending_anon_evt", anonymous: true)
        await waitForTrackRowsWithEvents(1)
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: "uid-retry-pending-anon-1", reference: nil, json: nil, send: false))
        let mock = MockMobileIngestClient()

        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 0)
        let tracks = DitoTrackOffline().offlinePersistedTracks
        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks.first?.retry, 1)
    }
    #endif

    func testLegacyTrackWithoutMark_waitsForIdentify_thenIsSentWithUser() async throws {
        let mock = MockMobileIngestClient()
        saveTrack(action: "legacy_evt")

        await DitoRetry(client: mock).runLoadOffline()
        XCTAssertEqual(mock.activityCallCount, 0)
        XCTAssertEqual(DitoTrackOffline().offlinePersistedTracks.count, 1)

        let userId = "uid-retry-legacy-1"
        savePostIdentify(userId: userId)
        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1)
        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, userId)
        XCTAssertEqual(trackEvents(req), ["legacy_evt"])
        XCTAssertTrue(DitoTrackOffline().offlinePersistedTracks.isEmpty)
    }

    #if DEBUG
    func testMixedQueue_afterIdentify_sendsAnonymousAndOwnedBatchesWithTheirUserIds() async throws {
        DeviceIdProvider.setForTests("device-retry-mixed-1")
        let mock = MockMobileIngestClient()
        saveTrack(action: "mixed_anon_evt", anonymous: true)
        saveTrack(action: "mixed_owned_evt")
        let userId = "uid-retry-mixed-1"
        savePostIdentify(userId: userId)

        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 2)
        let anonymousReq = try XCTUnwrap(mock.allActivityRequests.first { $0.userID.isEmpty })
        XCTAssertEqual(trackEvents(anonymousReq), ["mixed_anon_evt"])
        XCTAssertFalse(
            anonymousReq.activities.contains { $0.type == .activityIdentify },
            "com usuário logado não se envia Identify anônimo"
        )
        let ownedReq = try XCTUnwrap(mock.allActivityRequests.first { $0.userID == userId })
        XCTAssertEqual(trackEvents(ownedReq), ["mixed_owned_evt"])
        XCTAssertTrue(DitoTrackOffline().offlinePersistedTracks.isEmpty)
    }

    #endif

    func testLoadOffline_postIdentify_pendingRegister_ingestFails_keepsTokenJsonAndIncrementsRetry() async throws {
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = false
        savePostIdentify(userId: "uid-retry-register-fail-1")
        let registerJson = try XCTUnwrap(makeTokenRequest(token: "fcm-register-fail").toString)
        XCTAssertTrue(DitoNotificationRegisterDataManager().save(with: registerJson, retry: 0))

        await DitoRetry(client: mock).runLoadOffline()

        let pending = try XCTUnwrap(DitoNotificationRegisterDataManager().fetch)
        XCTAssertEqual(pending.json, registerJson)
        XCTAssertEqual(pending.retry, 1)
    }

    private func hasTokenRegister(_ request: Mobileingest_V1_Request, token: String) -> Bool {
        request.activities.contains { activity in
            guard let oneOf = activity.activity, case .tokenRegister(let reg) = oneOf else { return false }
            return reg.token == token
        }
    }

    private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTAssertTrue(condition(), "timeout à espera da condição")
    }

    func testRetryIdentifySucceeds_resendsLastTokenWithUser() async throws {
        let mock = MockMobileIngestClient()
        let userId = "uid-retry-token-resend-1"
        let token = "fcm-retry-token-resend"
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: nil, json: makeSignup().toString, send: false))
        UserDefaults.lastPushToken = token

        await DitoRetry(client: mock).runLoadOffline()

        await waitUntil {
            mock.allActivityRequests.contains { $0.userID == userId && self.hasTokenRegister($0, token: token) }
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(tokenRegisterRequests(mock, userId: userId, token: token).count, 1)
    }

    #if DEBUG
    func testIdentifySuccess_withAnonymousRegisterSlotForSameToken_sendsTokenOnlyWithUser() async throws {
        DeviceIdProvider.setForTests("device-login-race-1")
        let token = "fcm-login-race"
        UserDefaults.lastPushToken = token
        XCTAssertTrue(DitoNotificationRegisterDataManager().save(
            with: makeTokenRequest(token: token).toString,
            retry: 0,
            anonymous: true
        ))
        let mock = MockMobileIngestClient()
        let userId = "uid-login-race-1"

        DitoIdentify(retry: DitoRetry(client: mock), client: mock)
            .identify(id: userId, data: DitoUser(email: "race@example.com"))

        await waitUntil {
            mock.allActivityRequests.contains { $0.userID == userId && self.hasTokenRegister($0, token: token) }
        }
        await waitUntil { DitoNotificationRegisterDataManager().fetch == nil }
        XCTAssertFalse(
            mock.allActivityRequests.contains { $0.userID.isEmpty && self.hasTokenRegister($0, token: token) },
            "depois do login o token não pode sair como anônimo"
        )
    }
    #endif

    private func tokenRegisterRequests(_ mock: MockMobileIngestClient, userId: String, token: String) -> [Mobileingest_V1_Request] {
        mock.allActivityRequests.filter { $0.userID == userId && hasTokenRegister($0, token: token) }
    }

    func testPendingIdentify_anonymousSlotWithLastToken_isNotSentAnonymously_andTokenGoesOnceWithUser() async throws {
        let token = "fcm-pending-anon-slot"
        let userId = "uid-pending-anon-slot-1"
        UserDefaults.lastPushToken = token
        XCTAssertTrue(DitoNotificationRegisterDataManager().save(
            with: makeTokenRequest(token: token).toString,
            retry: 0,
            anonymous: true
        ))
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: nil, json: makeSignup().toString, send: false))
        let mock = MockMobileIngestClient()

        await DitoRetry(client: mock).runLoadOffline()
        await waitUntil { !self.tokenRegisterRequests(mock, userId: userId, token: token).isEmpty }
        XCTAssertEqual(DitoNotificationRegisterDataManager().fetch?.anonymous, true)

        await DitoRetry(client: mock).runLoadOffline()
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertNil(DitoNotificationRegisterDataManager().fetch)
        XCTAssertEqual(tokenRegisterRequests(mock, userId: userId, token: token).count, 1)
        XCTAssertTrue(tokenRegisterRequests(mock, userId: "", token: token).isEmpty)
    }

    func testIdentifyConfirmedByRetry_ownedSlotWithLastToken_sendsTokenOnceWithUser() async throws {
        let token = "fcm-owned-slot"
        let userId = "uid-owned-slot-1"
        UserDefaults.lastPushToken = token
        XCTAssertTrue(DitoNotificationRegisterDataManager().save(with: makeTokenRequest(token: token).toString, retry: 0))
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: nil, json: makeSignup().toString, send: false))
        let mock = MockMobileIngestClient()

        await DitoRetry(client: mock).runLoadOffline()
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(tokenRegisterRequests(mock, userId: userId, token: token).count, 1)
        XCTAssertNil(DitoNotificationRegisterDataManager().fetch)
    }

    func testIdentifyImmediateSuccess_ownedSlotWithLastToken_sendsTokenOnceWithUser() async throws {
        let token = "fcm-owned-slot-identify"
        let userId = "uid-owned-slot-identify-1"
        UserDefaults.lastPushToken = token
        XCTAssertTrue(DitoNotificationRegisterDataManager().save(with: makeTokenRequest(token: token).toString, retry: 0))
        let mock = MockMobileIngestClient()

        DitoIdentify(retry: DitoRetry(client: mock), client: mock)
            .identify(id: userId, data: DitoUser(email: "owned-slot@example.com"))

        await waitUntil { DitoNotificationRegisterDataManager().fetch == nil }
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(tokenRegisterRequests(mock, userId: userId, token: token).count, 1)
    }

    func testIdentifyConfirmed_ownedSlotWithLastTokenAtMaxRetries_tokenStillReachesUser() async throws {
        let token = "fcm-owned-slot-exhausted"
        let userId = "uid-owned-slot-exhausted-1"
        UserDefaults.lastPushToken = token
        XCTAssertTrue(DitoNotificationRegisterDataManager().save(
            with: makeTokenRequest(token: token).toString,
            retry: DitoRetry.maxRetries
        ))
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: nil, json: makeSignup().toString, send: false))
        let mock = MockMobileIngestClient()

        await DitoRetry(client: mock).runLoadOffline()
        await waitUntil { !self.tokenRegisterRequests(mock, userId: userId, token: token).isEmpty }
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(tokenRegisterRequests(mock, userId: userId, token: token).count, 1)
        XCTAssertNil(DitoNotificationRegisterDataManager().fetch)
    }

    private func identifyAndWait(_ sut: DitoIdentify, userId: String) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sut.identify(id: userId, data: DitoUser(email: "repeat@example.com")) { _ in cont.resume() }
        }
    }

    func testIdentifyTwiceWithSameUserAndToken_registersTokenOnce() async throws {
        let token = "fcm-identify-twice"
        let userId = "uid-identify-twice-1"
        UserDefaults.lastPushToken = token
        let mock = MockMobileIngestClient()
        let sut = DitoIdentify(retry: DitoRetry(client: mock), client: mock)

        await identifyAndWait(sut, userId: userId)
        await waitUntil { UserDefaults.lastUserTokenRegister != nil }
        await identifyAndWait(sut, userId: userId)
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(tokenRegisterRequests(mock, userId: userId, token: token).count, 1)
    }

    func testIdentifyWithAnotherUser_resendsToken() async throws {
        let token = "fcm-identify-other-user"
        UserDefaults.lastPushToken = token
        let mock = MockMobileIngestClient()
        let sut = DitoIdentify(retry: DitoRetry(client: mock), client: mock)

        await identifyAndWait(sut, userId: "uid-identify-first-1")
        await waitUntil { UserDefaults.lastUserTokenRegister != nil }
        await identifyAndWait(sut, userId: "uid-identify-second-1")

        await waitUntil { !self.tokenRegisterRequests(mock, userId: "uid-identify-second-1", token: token).isEmpty }
        XCTAssertEqual(tokenRegisterRequests(mock, userId: "uid-identify-first-1", token: token).count, 1)
    }

    func testIdentifyAgainAfterTokenChange_registersNewToken() async throws {
        let userId = "uid-identify-new-token-1"
        UserDefaults.lastPushToken = "fcm-identify-token-a"
        let mock = MockMobileIngestClient()
        let sut = DitoIdentify(retry: DitoRetry(client: mock), client: mock)

        await identifyAndWait(sut, userId: userId)
        await waitUntil { UserDefaults.lastUserTokenRegister != nil }
        UserDefaults.lastPushToken = "fcm-identify-token-b"
        await identifyAndWait(sut, userId: userId)

        await waitUntil { !self.tokenRegisterRequests(mock, userId: userId, token: "fcm-identify-token-b").isEmpty }
    }
}
