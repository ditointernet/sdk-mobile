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

    func testLoadOffline_identifyNotSent_firstActivityFails_tracksRemainAndNoFurtherActivityCalls() async throws {
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = false

        let userId = "uid-retry-identify-fail-1"
        let track = DitoTrack()
        track.track(data: DitoEvent(action: "retry_evt_fail_a", customData: nil))
        track.track(data: DitoEvent(action: "retry_evt_fail_b", customData: nil))
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
        let track = DitoTrack()
        track.track(data: DitoEvent(action: "retry_evt_ok_a", customData: nil))
        track.track(data: DitoEvent(action: "retry_evt_ok_b", customData: nil))
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
}
