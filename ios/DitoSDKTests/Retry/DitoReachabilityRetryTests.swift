import XCTest
@testable import DitoSDK

#if DEBUG
final class DitoReachabilityRetryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Dito.resetFacadeIsolationState()
        TestHelpers.resetAllState()
        Dito.appKey = "unit-reach-retry-app-key"
        Dito.appSecret = ""
        Dito.signature = "unit-reach-retry-signature"
        Dito.apiKey = ""
        Dito.bundleId = "br.com.dito.sdk.unit.tests"
        _ = DitoCoreDataManager.shared.persistentContainer
    }

    override func tearDown() {
        Dito.testIdentifyTrackIngestClient = nil
        Dito.resetFacadeIsolationState()
        TestHelpers.resetAllState()
        Dito.appKey = ""
        Dito.appSecret = ""
        Dito.signature = ""
        Dito.apiKey = ""
        Dito.bundleId = ""
        super.tearDown()
    }

    private func waitForMainQueueDrained() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                cont.resume()
            }
        }
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

    private func waitUntilTracksFlushedOrFail(mock: MockMobileIngestClient, timeout: TimeInterval = 10) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if DitoTrackOffline().offlinePersistedTracks.isEmpty, mock.activityCallCount > 0 {
                return
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail(
            "loadOffline não processou tracks; activityCallCount=\(mock.activityCallCount) tracks=\(DitoTrackOffline().offlinePersistedTracks.count)"
        )
    }

    private func makeSignup() -> DitoSignupRequest {
        DitoSignupRequest(
            platformAppKey: Dito.appKey.isEmpty ? Dito.apiKey : Dito.appKey,
            sha1Signature: Dito.signature,
            userData: DitoUser(email: "reachability@example.com")
        )
    }

    func testReachabilityChanged_whenConnectionBecomesAvailable_loadsOfflineAndClearsPersistedTracks() async throws {
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = true
        Dito.testIdentifyTrackIngestClient = mock

        Dito.setReachabilityConnectionOverrideForTests(.unavailable)
        Dito.configure(appKey: Dito.appKey, appSecret: "plain-secret-for-reach-test")
        await waitForMainQueueDrained()

        let userId = "uid-reach-retry-1"
        let track = DitoTrack()
        track.track(data: DitoEvent(action: "reach_retry_evt_a", customData: nil))
        track.track(data: DitoEvent(action: "reach_retry_evt_b", customData: nil))
        await waitForTrackRowsWithEvents(2)

        let signup = makeSignup()
        guard let signupJson = signup.toString else {
            XCTFail("signup json")
            return
        }
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: signupJson, send: false))
        XCTAssertEqual(DitoIdentifyOffline.shared.getIdentify?.send, false)
        XCTAssertEqual(DitoTrackOffline().offlinePersistedTracks.count, 2)

        await MainActor.run {
            Dito.setReachabilityConnectionOverrideForTests(.wifi)
            Dito.postReachabilityChangedNotificationForTests()
        }

        await waitUntilTracksFlushedOrFail(mock: mock, timeout: 10)

        XCTAssertEqual(DitoIdentifyOffline.shared.getIdentify?.send, true)
        XCTAssertTrue(DitoTrackOffline().offlinePersistedTracks.isEmpty)
        XCTAssertGreaterThanOrEqual(mock.activityCallCount, 2)
    }
}
#endif
