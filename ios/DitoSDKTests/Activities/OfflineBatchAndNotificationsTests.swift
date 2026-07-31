import XCTest
@testable import DitoSDK

final class OfflineBatchAndNotificationsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestHelpers.resetAllState()
        Dito.appKey = "unit-test-app-key"
        Dito.appSecret = ""
        Dito.signature = "unit-test-signature"
        Dito.apiKey = ""
        Dito.bundleId = "br.com.dito.sdk.unit.tests"
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

    private func waitForActivityCalls(_ mock: MockMobileIngestClient, count: Int, timeout: TimeInterval = 10) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if mock.activityCallCount >= count { return }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("timed out waiting for \(count) ingest call(s); got \(mock.activityCallCount)")
    }

    private func waitForTrackPersistedCount(_ count: Int, timeout: TimeInterval = 10) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if DitoTrackDataManager().fetchOfflinePersistedTracks().count >= count { return }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("timed out waiting for \(count) track row(s); got \(DitoTrackDataManager().fetchOfflinePersistedTracks().count)")
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
        XCTFail("timed out waiting for \(count) track rows with non-empty event; count=\(rows.count) eventsNil=\(rows.map { $0.event == nil })")
    }

    func testTrackWithoutIdentify_persistsToCoreData() async throws {
        XCTAssertTrue(DitoTrackDataManager().fetchOfflinePersistedTracks().isEmpty)

        let sut = DitoTrack()
        let event = DitoEvent(action: "offline_queue_no_identify_alpha", customData: nil)
        sut.track(data: event)

        await waitForTrackRowsWithEvents(1)

        let tracks = DitoTrackDataManager().fetchOfflinePersistedTracks()
        XCTAssertEqual(tracks.count, 1)
        let json = try XCTUnwrap(tracks.first?.event)
        let decoded = try XCTUnwrap(json.convertToObject(type: DitoEventRequest.self))
        XCTAssertEqual(decoded.event.action, event.action)
    }

    func testIdentifyThenLoadOffline_sendsSingleBatchForPendingTracks() async throws {
        XCTAssertTrue(DitoTrackDataManager().fetchOfflinePersistedTracks().isEmpty)

        let trackClient = MockMobileIngestClient()
        let userId = "uid-offline-batch-1"

        let enqueue = DitoTrack()
        enqueue.track(data: DitoEvent(action: "batch_evt_a", customData: nil))
        enqueue.track(data: DitoEvent(action: "batch_evt_b", customData: nil))

        await waitForTrackRowsWithEvents(2)
        let persistedBeforeIdentify = DitoTrackDataManager().fetchOfflinePersistedTracks()
        XCTAssertEqual(persistedBeforeIdentify.count, 2, "tracks should persist offline before identify")
        for row in persistedBeforeIdentify {
            XCTAssertNotNil(
                row.event.flatMap { $0.convertToObject(type: DitoEventRequest.self) },
                "persisted track JSON should decode"
            )
        }
        XCTAssertEqual(DitoTrackOffline().offlinePersistedTracks.count, 2)
        XCTAssertNil(DitoTrackOffline().reference)

        let signup = DitoSignupRequest(
            platformAppKey: Dito.appKey.isEmpty ? Dito.apiKey : Dito.appKey,
            sha1Signature: Dito.signature,
            userData: DitoUser(email: "batch@example.com")
        )
        guard let signupJson = signup.toString else {
            XCTFail("signup json")
            return
        }
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: signupJson, send: true))
        XCTAssertEqual(DitoIdentifyOffline.shared.getIdentify?.reference, userId)
        XCTAssertEqual(DitoTrackOffline().reference, userId)

        XCTAssertTrue(DitoIdentifyOffline.shared.getIdentify?.send == true)

        let retry = DitoRetry(client: trackClient)
        await retry.runLoadOffline()

        guard let batchReq = trackClient.allActivityRequests.first(where: { $0.activities.count >= 2 }) else {
            XCTFail(
                "expected one ingest request with at least 2 activities; callCount=\(trackClient.activityCallCount) sizes=\(trackClient.allActivityRequests.map { $0.activities.count })"
            )
            return
        }
        XCTAssertEqual(batchReq.userID, userId)
        XCTAssertGreaterThanOrEqual(batchReq.activities.count, 2)
        let trackActivities = batchReq.activities.filter { $0.type == .activityTrack }
        XCTAssertGreaterThanOrEqual(trackActivities.count, 2)
    }

    func testGetNotifications_returnsInsertedRecords() async throws {
        _ = DitoCoreDataManager.shared.persistentContainer

        let nid = "nid-getnotif-\(UUID().uuidString)"
        let title = "Título integração getNotifications"
        DitoNotificationCoreDataManager.shared.insert(
            notificationId: nid,
            title: title,
            message: "Corpo",
            link: "https://example.test/get"
        )

        try await Task.sleep(nanoseconds: 150_000_000)

        let list = Dito.shared.getNotifications()
        let match = list.first { $0.notificationId == nid }
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.title, title)
    }
}
