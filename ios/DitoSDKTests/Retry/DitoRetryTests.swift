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

    private func saveTrack(action: String, anonymous: Bool = false, userId: String? = nil) {
        let request = DitoEventRequest(
            platformAppKey: Dito.appKey,
            sha1Signature: Dito.signature,
            event: DitoEvent(action: action, customData: nil)
        )
        XCTAssertTrue(DitoTrackDataManager().save(event: request.toString, anonymous: anonymous, userId: userId))
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
        UserDefaults.lastPushToken = token

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

    func testLoadOffline_pendingReceiveWithoutNotificationId_isDroppedWithoutSending() async throws {
        let mock = MockMobileIngestClient()
        Dito.testNotificationReceivedIngestClient = mock
        addTeardownBlock { Dito.testNotificationReceivedIngestClient = nil }
        DitoNotificationOffline().notificationReceive(DitoNotificationReceivePending(
            userId: "uid-retry-receive-empty",
            token: "fcm-retry-receive-empty",
            notification: "",
            logId: "log-retry-receive-empty",
            notificationName: "Campanha antiga"
        ))
        XCTAssertEqual(DitoNotificationOffline().getNotificationReceive.count, 1)

        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 0)
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
        UserDefaults.lastPushToken = "fcm-anon-register"
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

    func testOwnedTracksOfDifferentUsers_areSentInSeparateRequests_legacyRowWithCurrentUser() async throws {
        saveTrack(action: "owner_a_evt", userId: "uid-retry-owner-a")
        saveTrack(action: "owner_b_evt", userId: "uid-retry-owner-b")
        saveTrack(action: "owner_legacy_evt")
        let currentUser = "uid-retry-owner-current"
        savePostIdentify(userId: currentUser)
        let mock = MockMobileIngestClient()

        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 3)
        var eventsByUser: [String: [String]] = [:]
        for req in mock.allActivityRequests {
            eventsByUser[req.userID, default: []] += trackEvents(req)
        }
        XCTAssertEqual(eventsByUser, [
            "uid-retry-owner-a": ["owner_a_evt"],
            "uid-retry-owner-b": ["owner_b_evt"],
            currentUser: ["owner_legacy_evt"],
        ])
        XCTAssertTrue(DitoTrackOffline().offlinePersistedTracks.isEmpty)
    }

    func testOwnedTracksOfTwoUsersFail_eachRowSpendsOneRetryAndKeepsItsOwner() async throws {
        saveTrack(action: "owner_fail_a_evt", userId: "uid-retry-owner-fail-a")
        saveTrack(action: "owner_fail_b_evt", userId: "uid-retry-owner-fail-b")
        savePostIdentify(userId: "uid-retry-owner-fail-current")
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = false

        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 2)
        XCTAssertEqual(DitoTrackOffline().offlinePersistedTracks.map(\.retry), [2, 2])
        XCTAssertEqual(
            Set(DitoTrackOffline().offlinePersistedTracks.compactMap(\.userId)),
            ["uid-retry-owner-fail-a", "uid-retry-owner-fail-b"]
        )
    }

    func testTrackWhileIdentifyOfAIsPending_logoutAndLoginOfB_retrySendsItWithUserA() async throws {
        let userA = "uid-retry-pending-owner-a"
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userA, reference: nil, json: makeSignup().toString, send: false))
        let offline = MockMobileIngestClient()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DitoTrack(client: offline).track(data: DitoEvent(action: "pending_owner_evt", customData: nil)) { _ in
                cont.resume()
            }
        }
        await waitForTrackRowsWithEvents(1)
        XCTAssertEqual(offline.activityCallCount, 0)
        XCTAssertEqual(DitoTrackOffline().offlinePersistedTracks.first?.userId, userA)

        DitoIdentifyOffline.shared.logout()
        savePostIdentify(userId: "uid-retry-pending-owner-b")
        let mock = MockMobileIngestClient()
        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1)
        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, userA)
        XCTAssertEqual(trackEvents(req), ["pending_owner_evt"])
        XCTAssertTrue(DitoTrackOffline().offlinePersistedTracks.isEmpty)
    }

    func testOwnedTrackOfA_identifyOfBPendingAndFailing_waitsWithoutSpendingRetry() async throws {
        saveTrack(action: "owner_waits_evt", userId: "uid-retry-waits-a")
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(
            id: "uid-retry-waits-b",
            reference: nil,
            json: makeSignup().toString,
            send: false
        ))
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = false

        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1)
        XCTAssertEqual(mock.lastActivityRequest?.activities.map(\.type), [.activityIdentify])
        XCTAssertEqual(DitoTrackOffline().offlinePersistedTracks.map(\.retry), [1])
    }

    func testOwnedTrackOfA_afterLogoutWithNobodyLogged_isSentWithUserA() async throws {
        let userA = "uid-retry-logged-out-a"
        savePostIdentify(userId: userA)
        saveTrack(action: "logged_out_evt", userId: userA)
        DitoIdentifyOffline.shared.logout()
        XCTAssertNil(DitoTrackOffline().reference)
        let mock = MockMobileIngestClient()

        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1)
        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, userA)
        XCTAssertEqual(trackEvents(req), ["logged_out_evt"])
        XCTAssertTrue(DitoTrackOffline().offlinePersistedTracks.isEmpty)
    }

    func testQueuedClick_withoutLoggedUser_isSentWithThePushUser() async throws {
        let pushUser = "uid-retry-click-no-login"
        XCTAssertTrue(DitoNotificationReadDataManager().save(
            with: makeClickRequest(notificationId: "notif-click-no-login", userId: pushUser).toString,
            retry: 0
        ))
        let mock = MockMobileIngestClient()

        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1)
        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, pushUser)
        XCTAssertEqual(req.activities.first?.trackPushClick.notification.notificationID, "notif-click-no-login")
        XCTAssertTrue(DitoNotificationReadDataManager().fetchAll.isEmpty)
    }

    func testQueuedClickOfUserA_withUserBLogged_isSentWithUserA() async throws {
        let pushUser = "uid-retry-click-owner-a"
        XCTAssertTrue(DitoNotificationReadDataManager().save(
            with: makeClickRequest(notificationId: "notif-click-owner-a", userId: pushUser).toString,
            retry: 0
        ))
        savePostIdentify(userId: "uid-retry-click-owner-b")
        let mock = MockMobileIngestClient()

        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1)
        XCTAssertEqual(mock.lastActivityRequest?.userID, pushUser)
        XCTAssertTrue(DitoNotificationReadDataManager().fetchAll.isEmpty)
    }

    func testQueuedClickWithoutIdentifier_waitsForLogin_thenIsSentWithCurrentUser() async throws {
        XCTAssertTrue(DitoNotificationReadDataManager().save(
            with: makeClickRequest(notificationId: "notif-click-legacy", userId: "").toString,
            retry: 0
        ))
        let mock = MockMobileIngestClient()

        await DitoRetry(client: mock).runLoadOffline()
        XCTAssertEqual(mock.activityCallCount, 0)
        XCTAssertEqual(DitoNotificationReadDataManager().fetchAll.map(\.retry), [0])

        let currentUser = "uid-retry-click-legacy"
        savePostIdentify(userId: currentUser)
        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1)
        XCTAssertEqual(mock.lastActivityRequest?.userID, currentUser)
        XCTAssertTrue(DitoNotificationReadDataManager().fetchAll.isEmpty)
    }

    #if DEBUG
    func testOwnedTrackQueuedByUserA_logoutAndLoginOfB_retrySendsItWithUserA() async throws {
        DeviceIdProvider.setForTests("device-retry-owner-switch-1")
        let userA = "uid-retry-owner-switch-a"
        savePostIdentify(userId: userA)
        let failing = MockMobileIngestClient()
        failing.shouldSucceed = false
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DitoTrack(client: failing).track(data: DitoEvent(action: "owner_switch_evt", customData: nil)) { _ in
                cont.resume()
            }
        }
        await waitForTrackRowsWithEvents(1)
        XCTAssertEqual(DitoTrackOffline().offlinePersistedTracks.first?.userId, userA)

        DitoIdentifyOffline.shared.logout()
        savePostIdentify(userId: "uid-retry-owner-switch-b")
        let mock = MockMobileIngestClient()
        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1)
        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, userA)
        XCTAssertEqual(trackEvents(req), ["owner_switch_evt"])
        XCTAssertTrue(DitoTrackOffline().offlinePersistedTracks.isEmpty)
    }

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
        XCTAssertEqual(
            anonymousReq.activities.map(\.type),
            [.activityIdentify, .activityTrack],
            "linha anônima de antes do login leva o Identify anônimo do aparelho"
        )
        let ownedReq = try XCTUnwrap(mock.allActivityRequests.first { $0.userID == userId })
        XCTAssertEqual(trackEvents(ownedReq), ["mixed_owned_evt"])
        XCTAssertTrue(DitoTrackOffline().offlinePersistedTracks.isEmpty)
    }

    func testAnonymousRowQueuedBeforeLogin_retryAfterLogin_sendsAnonymousIdentifyAndSavesMark() async throws {
        let deviceId = "device-retry-anon-after-login-1"
        DeviceIdProvider.setForTests(deviceId)
        saveTrack(action: "anon_before_login_evt", anonymous: true)
        await waitForTrackRowsWithEvents(1)
        savePostIdentify(userId: "uid-retry-anon-after-login-1")
        let mock = MockMobileIngestClient()

        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1)
        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, "")
        XCTAssertEqual(req.device.deviceID, deviceId)
        XCTAssertEqual(req.activities.map(\.type), [.activityIdentify, .activityTrack])
        XCTAssertEqual(trackEvents(req), ["anon_before_login_evt"])
        XCTAssertEqual(UserDefaults.anonymousIdentifyMark, ["device_id": deviceId, "sdk_version": req.sdk.version])
        XCTAssertTrue(DitoTrackOffline().offlinePersistedTracks.isEmpty)
    }

    func testRetryWithoutDeviceId_sendsNothingAndSpendsNoRetry_thenSendsEverythingWithDeviceId() async throws {
        DeviceIdProvider.setForTests("")
        let userId = "uid-retry-no-device-1"
        let token = "fcm-retry-no-device"
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: nil, json: makeSignup().toString, send: false))
        saveTrack(action: "no_device_owned_evt")
        saveTrack(action: "no_device_anon_evt", anonymous: true)
        XCTAssertTrue(DitoTrackDataManager().save(
            event: DitoEventRequest(
                platformAppKey: Dito.appKey,
                sha1Signature: Dito.signature,
                event: DitoEvent(action: "no_device_exhausted_evt", customData: nil)
            ).toString,
            retry: DitoRetry.maxRetries
        ))
        let anonUnregisterToken = "fcm-retry-no-device-anon-unregister"
        XCTAssertTrue(DitoNotificationUnregisterDataManager().save(
            with: makeTokenRequest(token: anonUnregisterToken).toString,
            retry: 0,
            anonymous: true
        ))
        UserDefaults.lastPushToken = token
        XCTAssertTrue(DitoNotificationRegisterDataManager().save(with: makeTokenRequest(token: token).toString, retry: 0))
        XCTAssertTrue(DitoNotificationReadDataManager().save(
            with: makeClickRequest(notificationId: "notif-retry-no-device", userId: userId).toString,
            retry: 0
        ))
        let receive = DitoNotificationReceivePending(
            userId: userId,
            token: token,
            notification: "notif-retry-no-device-receive",
            logId: "log-retry-no-device-receive",
            notificationName: "campanha-sem-device"
        )
        XCTAssertTrue(DitoNotificationReceiveDataManager().save(with: receive.toString, retry: 0))
        await waitForTrackRowsWithEvents(3)
        let mock = MockMobileIngestClient()

        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 0)
        XCTAssertEqual(DitoIdentifyOffline.shared.getIdentify?.send, false)
        XCTAssertEqual(
            DitoTrackOffline().offlinePersistedTracks.map(\.retry).sorted(),
            [1, 1, DitoRetry.maxRetries],
            "sem device_id nem a linha esgotada é descartada, e nenhuma tentativa é gasta"
        )
        XCTAssertEqual(DitoNotificationUnregisterDataManager().fetch?.retry, 0)
        XCTAssertEqual(DitoNotificationUnregisterDataManager().fetch?.anonymous, true)
        XCTAssertEqual(DitoNotificationRegisterDataManager().fetch?.retry, 0)
        XCTAssertEqual(DitoNotificationReadDataManager().fetchAll.map(\.retry), [0])
        XCTAssertEqual(DitoNotificationReceiveDataManager().fetchAll.map(\.retry), [0])

        DeviceIdProvider.setForTests("device-retry-back-1")
        await DitoRetry(client: mock).runLoadOffline()
        // Anonymous rows are checked before the identify in a run, so they go on the next one.
        await DitoRetry(client: mock).runLoadOffline()

        let requests = mock.allActivityRequests
        XCTAssertFalse(requests.isEmpty)
        XCTAssertTrue(requests.allSatisfy { $0.device.deviceID == "device-retry-back-1" })
        XCTAssertEqual(DitoIdentifyOffline.shared.getIdentify?.send, true)
        XCTAssertTrue(requests.contains { self.hasTokenRegister($0, token: token) })
        XCTAssertTrue(requests.contains { req in req.activities.contains { $0.type == .activityTrack && $0.trackPushClick.notification.notificationID == "notif-retry-no-device" } })
        XCTAssertEqual(
            Set(requests.flatMap { self.trackEvents($0) }),
            ["no_device_owned_evt", "no_device_anon_evt"]
        )
        XCTAssertTrue(requests.contains { req in
            req.activities.contains { $0.trackPushReceipt.notification.notificationID == "notif-retry-no-device-receive" }
        })
        XCTAssertTrue(requests.contains { req in
            req.userID.isEmpty && req.activities.contains {
                $0.tokenUnregister.token == anonUnregisterToken
            }
        })
        XCTAssertNil(DitoNotificationUnregisterDataManager().fetch)
        XCTAssertTrue(DitoTrackOffline().offlinePersistedTracks.isEmpty)
        XCTAssertNil(DitoNotificationRegisterDataManager().fetch)
        XCTAssertTrue(DitoNotificationReadDataManager().fetchAll.isEmpty)
        XCTAssertTrue(DitoNotificationReceiveDataManager().fetchAll.isEmpty)
    }
    #endif

    func testQueuedRegisterOfReplacedToken_isDroppedWithoutSending() async throws {
        savePostIdentify(userId: "uid-retry-replaced-token-1")
        UserDefaults.lastPushToken = "fcm-replaced-new"
        XCTAssertTrue(DitoNotificationRegisterDataManager().save(
            with: makeTokenRequest(token: "fcm-replaced-old").toString,
            retry: 0
        ))
        let mock = MockMobileIngestClient()

        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 0)
        XCTAssertNil(DitoNotificationRegisterDataManager().fetch)
    }

    func testQueuedAnonymousRegister_withoutLastToken_isSentAnonymously() async throws {
        let token = "fcm-anon-no-last-token"
        XCTAssertTrue(DitoNotificationRegisterDataManager().save(
            with: makeTokenRequest(token: token).toString,
            retry: 0,
            anonymous: true
        ))
        let mock = MockMobileIngestClient()

        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(mock.activityCallCount, 1)
        XCTAssertEqual(tokenRegisterRequests(mock, userId: "", token: token).count, 1)
        XCTAssertNil(DitoNotificationRegisterDataManager().fetch)
    }

    func testQueuedOwnedRegister_withoutLastToken_isSentWithUser() async throws {
        let userId = "uid-retry-owned-no-last-token-1"
        let token = "fcm-owned-no-last-token"
        savePostIdentify(userId: userId)
        XCTAssertTrue(DitoNotificationRegisterDataManager().save(with: makeTokenRequest(token: token).toString, retry: 0))
        XCTAssertNil(DitoNotificationRegisterDataManager().fetch?.anonymous)
        let mock = MockMobileIngestClient()

        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(tokenRegisterRequests(mock, userId: userId, token: token).count, 1)
        XCTAssertNil(DitoNotificationRegisterDataManager().fetch)
    }

    func testLoadOffline_postIdentify_pendingRegister_ingestFails_keepsTokenJsonAndIncrementsRetry() async throws {
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = false
        savePostIdentify(userId: "uid-retry-register-fail-1")
        UserDefaults.lastPushToken = "fcm-register-fail"
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
        // The register with the user succeeded, so the anonymous slot of the same token goes with it.
        await waitUntil { DitoNotificationRegisterDataManager().fetch == nil }

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
