import UIKit
import XCTest
@testable import DitoSDK

#if DEBUG
final class OfflineQueueTimestampTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Dito.resetFacadeIsolationState()
        TestHelpers.resetAllState()
        Dito.appKey = "unit-queue-ts-app-key"
        Dito.appSecret = ""
        Dito.signature = "unit-queue-ts-signature"
        Dito.apiKey = ""
        Dito.bundleId = "br.com.dito.sdk.unit.tests"
        _ = DitoCoreDataManager.shared.persistentContainer
    }

    override func tearDown() {
        Dito.reconnectRetryDelay = 5
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

    // MARK: - Helpers

    private func floorToSecond(_ date: Date) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }

    private func savePostIdentify(userId: String) {
        let signup = DitoSignupRequest(
            platformAppKey: Dito.appKey,
            sha1Signature: Dito.signature,
            userData: DitoUser(email: "queue-ts@example.com")
        )
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: signup.toString, send: true))
    }

    private func saveTrack(_ event: DitoEvent) {
        let request = DitoEventRequest(platformAppKey: Dito.appKey, sha1Signature: Dito.signature, event: event)
        XCTAssertTrue(DitoTrackDataManager().save(event: request.toString))
    }

    private func trackAndWait(_ sut: DitoTrack, action: String) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sut.track(data: DitoEvent(action: action, customData: nil)) { _ in cont.resume() }
        }
    }

    private func waitUntil(timeout: TimeInterval = 10, _ condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("timed out waiting for condition")
    }

    private func queueCount() -> Int {
        DitoTrackDataManager().fetchOfflinePersistedTracks().count
    }

    private func trackActivities(_ requests: [Mobileingest_V1_Request]) -> [Mobileingest_V1_Activity] {
        requests.flatMap { $0.activities.filter { $0.type == .activityTrack } }
    }

    private func sentEvents(_ requests: [Mobileingest_V1_Request]) -> [String] {
        trackActivities(requests).compactMap { activity in
            guard let oneOf = activity.activity, case .track(let track) = oneOf else { return nil }
            return track.event
        }
    }

    // MARK: - Mapper

    func testMapper_isoCreatedAt_becomesActivityTimestamp() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let activity = ActivityMapper().mapFromDitoEvent(DitoEvent(action: "iso_evt", createdAt: date))
        XCTAssertEqual(activity.timestamp.seconds, 1_700_000_000)
    }

    func testMapper_nilCreatedAt_usesNow() {
        let activity = ActivityMapper().mapFromDitoEvent(DitoEvent(action: "nil_evt"))
        XCTAssertLessThan(abs(activity.timestamp.date.timeIntervalSinceNow), 5)
    }

    func testMapper_legacyDateOnlyCreatedAt_usesNow() {
        var event = DitoEvent(action: "legacy_evt")
        event.createdAt = "2020-01-15"
        let activity = ActivityMapper().mapFromDitoEvent(event)
        XCTAssertLessThan(abs(activity.timestamp.date.timeIntervalSinceNow), 5)
    }

    // MARK: - DitoTrack

    func testTrackOnline_sendsCreatedAtAsTimestamp() async throws {
        savePostIdentify(userId: "uid-queue-ts-online")
        let mock = MockMobileIngestClient()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DitoTrack(client: mock, onSent: {}).track(
                data: DitoEvent(action: "online_ts_evt", createdAt: createdAt)
            ) { _ in cont.resume() }
        }

        let activity = try XCTUnwrap(trackActivities(mock.allActivityRequests).first)
        XCTAssertEqual(activity.timestamp.seconds, 1_700_000_000)
    }

    func testFailedTrack_identified_isResentWithCallTime() async throws {
        savePostIdentify(userId: "uid-queue-ts-failed")
        try await assertFailedTrackIsResentWithCallTime(anonymous: false)
    }

    func testFailedTrack_anonymous_isResentWithCallTime() async throws {
        DeviceIdProvider.setForTests("device-queue-ts-failed")
        try await assertFailedTrackIsResentWithCallTime(anonymous: true)
    }

    private func assertFailedTrackIsResentWithCallTime(anonymous: Bool) async throws {
        let failing = MockMobileIngestClient()
        failing.shouldSucceed = false

        let before = floorToSecond(Date())
        await trackAndWait(DitoTrack(client: failing, onSent: {}), action: "failed_ts_evt")
        await waitUntil { self.queueCount() == 1 }
        let after = Date()

        let row = try XCTUnwrap(DitoTrackDataManager().fetchOfflinePersistedTracks().first)
        XCTAssertEqual(row.anonymous, anonymous)
        let queued = try XCTUnwrap(row.event?.convertToObject(type: DitoEventRequest.self))
        XCTAssertNotNil(queued.event.createdAt)

        // Sending later than a second after the call is what tells call time from send time.
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let mock = MockMobileIngestClient()
        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertEqual(queueCount(), 0)
        let timestamp = try XCTUnwrap(trackActivities(mock.allActivityRequests).first).timestamp.date
        XCTAssertGreaterThanOrEqual(timestamp, before)
        XCTAssertLessThanOrEqual(timestamp, after)
    }

    func testTrackOnlineSuccess_flushesPendingQueue() async throws {
        savePostIdentify(userId: "uid-queue-ts-flush")
        saveTrack(DitoEvent(action: "pending_a"))
        saveTrack(DitoEvent(action: "pending_b"))
        await waitUntil { self.queueCount() == 2 }

        let mock = MockMobileIngestClient()
        let retry = DitoRetry(client: mock)

        await trackAndWait(DitoTrack(client: mock, onSent: { retry.loadOffline() }), action: "online_flush_evt")
        await waitUntil { self.queueCount() == 0 }

        XCTAssertEqual(Set(sentEvents(mock.allActivityRequests)), ["online_flush_evt", "pending_a", "pending_b"])
    }

    func testTokenOnlineSuccess_flushesPendingQueue() async throws {
        savePostIdentify(userId: "uid-queue-ts-token")
        saveTrack(DitoEvent(action: "pending_before_token"))
        await waitUntil { self.queueCount() == 1 }

        let mock = MockMobileIngestClient()
        let retry = DitoRetry(client: mock)
        let sut = DitoNotification(client: mock, onSent: { retry.loadOffline() })

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sut.registerToken(token: "fcm-queue-ts-token") { _ in cont.resume() }
        }
        await waitUntil { self.queueCount() == 0 }

        XCTAssertEqual(sentEvents(mock.allActivityRequests), ["pending_before_token"])
    }

    // MARK: - DitoRetry

    func testConcurrentLoadOffline_sendsEachRowOnce() async throws {
        savePostIdentify(userId: "uid-queue-ts-concurrent")
        let actions = ["concurrent_a", "concurrent_b", "concurrent_c"]
        actions.forEach { saveTrack(DitoEvent(action: $0)) }
        await waitUntil { self.queueCount() == 3 }

        let mock = MockMobileIngestClient()
        let sut = DitoRetry(client: mock)
        sut.loadOffline()
        sut.loadOffline()

        await waitUntil { self.queueCount() == 0 }
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(sentEvents(mock.allActivityRequests).sorted(), actions)
    }

    private func firstRowRetry() -> Int16? {
        DitoTrackDataManager().fetchOfflinePersistedTracks().first?.retry
    }

    private func captureScheduledPasses() -> ScheduledPasses {
        let scheduled = ScheduledPasses()
        DitoRetry.schedulePass = { delay, work in scheduled.add(delay, work) }
        return scheduled
    }

    func testFailedPass_skippedPassesRunOnceWhenBackoffEnds() async throws {
        let scheduled = captureScheduledPasses()
        DitoRetry.isOnline = { true }
        DitoRetry.now = { 1_000_000 }
        savePostIdentify(userId: "uid-queue-ts-backoff")
        saveTrack(DitoEvent(action: "backoff_evt"))
        await waitUntil { self.queueCount() == 1 }
        let failing = MockMobileIngestClient()
        failing.shouldSucceed = false

        DitoRetry(client: failing).loadOffline()
        await waitUntil { self.firstRowRetry() == 2 }
        try await Task.sleep(nanoseconds: 200_000_000)

        let mock = MockMobileIngestClient()
        DitoRetry.now = { 1_000_000 + DitoRetry.failureBackoff - 1 }
        DitoRetry(client: mock).loadOffline()
        DitoRetry(client: mock).loadOffline()
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mock.activityCallCount, 0, "dentro da janela a passada é adiada")
        XCTAssertEqual(firstRowRetry(), 2, "passada adiada não gasta tentativa")
        XCTAssertEqual(scheduled.all.count, 1, "adiamentos não se empilham")
        XCTAssertEqual(try XCTUnwrap(scheduled.all.first).delay, 1, accuracy: 0.001)

        DitoRetry.now = { 1_000_000 + DitoRetry.failureBackoff + 1 }
        try XCTUnwrap(scheduled.all.first).work.perform()
        await waitUntil { self.queueCount() == 0 }
        XCTAssertEqual(sentEvents(mock.allActivityRequests), ["backoff_evt"])
    }

    /// Leaves one failed pass behind (the row at retry 2) and one pass postponed to the end of the backoff.
    private func failPassAndPostponeNext(
        userId: String,
        action: String,
        mock: MockMobileIngestClient
    ) async throws -> ScheduledPasses {
        let scheduled = captureScheduledPasses()
        DitoRetry.now = { 4_000_000 }
        savePostIdentify(userId: userId)
        saveTrack(DitoEvent(action: action))
        await waitUntil { self.queueCount() == 1 }
        let failing = MockMobileIngestClient()
        failing.shouldSucceed = false
        DitoRetry(client: failing).loadOffline()
        await waitUntil { self.firstRowRetry() == 2 }
        try await Task.sleep(nanoseconds: 200_000_000)
        DitoRetry(client: mock).loadOffline()
        XCTAssertEqual(scheduled.all.count, 1)
        return scheduled
    }

    func testPostponedPass_offlineWhenBackoffEnds_doesNotRunNorSpendRetry() async throws {
        let mock = MockMobileIngestClient()
        let scheduled = try await failPassAndPostponeNext(
            userId: "uid-queue-ts-postponed-offline",
            action: "postponed_offline_evt",
            mock: mock
        )
        DitoRetry.isOnline = { false }
        DitoRetry.now = { 4_000_000 + DitoRetry.failureBackoff + 1 }

        try XCTUnwrap(scheduled.all.first).work.perform()
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(mock.activityCallCount, 0)
        XCTAssertEqual(firstRowRetry(), 2)
    }

    func testReconnect_cancelsPostponedPass() async throws {
        let mock = MockMobileIngestClient()
        Dito.testIdentifyTrackIngestClient = mock
        Dito.invalidateRetryCacheForTests()
        let scheduled = try await failPassAndPostponeNext(
            userId: "uid-queue-ts-reconnect-cancels",
            action: "reconnect_cancels_evt",
            mock: mock
        )
        let postponed = try XCTUnwrap(scheduled.all.first).work

        await MainActor.run {
            Dito.setReachabilityConnectionOverrideForTests(.wifi)
            Dito.shared.reachabilityChanged(Notification(name: .reachabilityChanged))
        }

        XCTAssertTrue(postponed.isCancelled)
        await waitUntil { self.queueCount() == 0 }
    }

    func testPassWithoutFailure_clearsBackoff() async throws {
        let mock = MockMobileIngestClient()
        _ = try await failPassAndPostponeNext(
            userId: "uid-queue-ts-clears-backoff",
            action: "clears_backoff_evt",
            mock: mock
        )

        DitoRetry(client: mock).loadOffline(ignoringBackoff: true)
        await waitUntil { self.queueCount() == 0 }
        try await Task.sleep(nanoseconds: 200_000_000)
        saveTrack(DitoEvent(action: "after_clear_evt"))
        await waitUntil { self.queueCount() == 1 }
        DitoRetry(client: mock).loadOffline()
        await waitUntil { self.queueCount() == 0 }

        XCTAssertEqual(sentEvents(mock.allActivityRequests), ["clears_backoff_evt", "after_clear_evt"])
    }

    func testPassWithoutFailure_cancelsPostponedPass() async throws {
        let mock = MockMobileIngestClient()
        let scheduled = try await failPassAndPostponeNext(
            userId: "uid-queue-ts-cancels-postponed",
            action: "cancels_postponed_evt",
            mock: mock
        )

        DitoRetry(client: mock).loadOffline(ignoringBackoff: true)
        await waitUntil { self.queueCount() == 0 }
        await waitUntil { scheduled.all.first?.work.isCancelled == true }
    }

    /// A failed pass leaves the backoff on and a pass postponed; `send` makes a live send through `mock`
    /// whose success triggers `retry`.
    private func assertLiveSuccessEndsBackoff(
        userId: String,
        action: String,
        send: (MockMobileIngestClient, DitoRetry) async -> Void
    ) async throws {
        let mock = MockMobileIngestClient()
        let scheduled = try await failPassAndPostponeNext(userId: userId, action: action, mock: mock)
        let postponed = try XCTUnwrap(scheduled.all.first).work

        await send(mock, DitoRetry(client: mock))

        await waitUntil { self.queueCount() == 0 }
        XCTAssertTrue(sentEvents(mock.allActivityRequests).contains(action))
        XCTAssertTrue(postponed.isCancelled)
    }

    func testLiveTrackSuccess_endsBackoffAndFlushesQueueNow() async throws {
        try await assertLiveSuccessEndsBackoff(userId: "uid-queue-ts-live-track", action: "live_track_backoff_evt") { mock, retry in
            await self.trackAndWait(DitoTrack(client: mock, onSent: { retry.loadOffline() }), action: "live_track_ok_evt")
        }
    }

    func testLiveTokenSuccess_endsBackoffAndFlushesQueueNow() async throws {
        try await assertLiveSuccessEndsBackoff(userId: "uid-queue-ts-live-token", action: "live_token_backoff_evt") { mock, retry in
            let sut = DitoNotification(client: mock, onSent: { retry.loadOffline() })
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                sut.registerToken(token: "fcm-queue-ts-live-token") { _ in cont.resume() }
            }
        }
    }

    func testLiveIdentifySuccess_endsBackoffAndFlushesQueueNow() async throws {
        let userId = "uid-queue-ts-live-identify"
        try await assertLiveSuccessEndsBackoff(userId: userId, action: "live_identify_backoff_evt") { mock, retry in
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                DitoIdentify(retry: retry, client: mock).identify(
                    id: userId,
                    data: DitoUser(email: "queue-ts@example.com")
                ) { _ in cont.resume() }
            }
        }
    }

    func testFailureBackoff_usesUptimeClock() {
        XCTAssertEqual(DitoRetry.now(), ProcessInfo.processInfo.systemUptime, accuracy: 1)
    }

    func testPostponedPass_readsConnectionOnMainQueue() async throws {
        DitoRetry.now = { 7_000_000 }
        savePostIdentify(userId: "uid-queue-ts-postponed-main")
        saveTrack(DitoEvent(action: "postponed_main_evt"))
        await waitUntil { self.queueCount() == 1 }
        let failing = MockMobileIngestClient()
        failing.shouldSucceed = false
        DitoRetry(client: failing).loadOffline()
        await waitUntil { self.firstRowRetry() == 2 }
        try await Task.sleep(nanoseconds: 200_000_000)

        let read = expectation(description: "conexão lida ao fim da janela")
        DitoRetry.isOnline = {
            XCTAssertTrue(Thread.isMainThread, "Reachability é lida na main")
            read.fulfill()
            return false
        }
        DitoRetry.now = { 7_000_000 + DitoRetry.failureBackoff - 0.05 }
        DitoRetry(client: failing).loadOffline()

        await fulfillment(of: [read], timeout: 5)
    }

    func testPassFromBeforeReset_doesNotEndCurrentPass() async throws {
        savePostIdentify(userId: "uid-queue-ts-reset-epoch")
        saveTrack(DitoEvent(action: "reset_epoch_evt"))
        await waitUntil { self.queueCount() == 1 }
        let previous = GatedFailingClient()
        DitoRetry(client: previous).loadOffline()
        await waitUntil { previous.recorder.activityCallCount == 1 }

        DitoRetry.resetForTests()
        let current = GatedFailingClient()
        DitoRetry(client: current).loadOffline()
        await waitUntil { current.recorder.activityCallCount == 1 }
        previous.open()
        await waitUntil { self.firstRowRetry() == 2 }
        try await Task.sleep(nanoseconds: 200_000_000)

        let mock = MockMobileIngestClient()
        DitoRetry(client: mock).loadOffline(ignoringBackoff: true)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mock.activityCallCount, 0, "a passada em curso segue sendo a única")
        current.open()
        await waitUntil { self.queueCount() == 0 }
        XCTAssertEqual(sentEvents(mock.allActivityRequests), ["reset_epoch_evt"])
    }

    func testPassQueuedDuringFailingPass_isPostponedWithoutSpendingRetry() async throws {
        let scheduled = captureScheduledPasses()
        DitoRetry.now = { 2_000_000 }
        savePostIdentify(userId: "uid-queue-ts-queued-during-fail")
        saveTrack(DitoEvent(action: "queued_during_fail_evt"))
        await waitUntil { self.queueCount() == 1 }
        let client = GatedFailingClient()
        let sut = DitoRetry(client: client)

        sut.loadOffline()
        await waitUntil { client.recorder.activityCallCount == 1 }
        sut.loadOffline()
        client.open()
        await waitUntil { self.firstRowRetry() == 2 }
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(client.recorder.activityCallCount, 1, "a passada enfileirada não roda dentro da janela")
        XCTAssertEqual(firstRowRetry(), 2)
        XCTAssertEqual(scheduled.all.count, 1, "fica agendada para o fim da janela")
    }

    func testReconnectPassQueuedDuringFailingPass_runsDespiteBackoff() async throws {
        let scheduled = captureScheduledPasses()
        DitoRetry.now = { 3_000_000 }
        savePostIdentify(userId: "uid-queue-ts-reconnect-queued")
        saveTrack(DitoEvent(action: "reconnect_queued_evt"))
        await waitUntil { self.queueCount() == 1 }
        let client = GatedFailingClient()
        let sut = DitoRetry(client: client)

        sut.loadOffline()
        await waitUntil { client.recorder.activityCallCount == 1 }
        sut.loadOffline(ignoringBackoff: true)
        client.open()
        await waitUntil { client.recorder.activityCallCount == 2 }
        await waitUntil { self.firstRowRetry() == 3 }

        XCTAssertTrue(scheduled.all.isEmpty)
    }

    func testSuccessfulPass_doesNotBlockNextPass() async throws {
        savePostIdentify(userId: "uid-queue-ts-no-backoff")
        saveTrack(DitoEvent(action: "ok_first_evt"))
        await waitUntil { self.queueCount() == 1 }
        let mock = MockMobileIngestClient()

        DitoRetry(client: mock).loadOffline()
        await waitUntil { self.queueCount() == 0 }
        try await Task.sleep(nanoseconds: 200_000_000)
        saveTrack(DitoEvent(action: "ok_second_evt"))
        await waitUntil { self.queueCount() == 1 }
        DitoRetry(client: mock).loadOffline()
        await waitUntil { self.queueCount() == 0 }

        XCTAssertEqual(sentEvents(mock.allActivityRequests), ["ok_first_evt", "ok_second_evt"])
    }

    func testResetFacadeIsolationState_clearsFailureBackoff() async throws {
        savePostIdentify(userId: "uid-queue-ts-reset-backoff")
        saveTrack(DitoEvent(action: "reset_backoff_evt"))
        await waitUntil { self.queueCount() == 1 }
        let failing = MockMobileIngestClient()
        failing.shouldSucceed = false
        DitoRetry(client: failing).loadOffline()
        await waitUntil { self.firstRowRetry() == 2 }
        try await Task.sleep(nanoseconds: 200_000_000)

        Dito.resetFacadeIsolationState()
        let mock = MockMobileIngestClient()
        DitoRetry(client: mock).loadOffline()

        await waitUntil { self.queueCount() == 0 }
        XCTAssertEqual(sentEvents(mock.allActivityRequests), ["reset_backoff_evt"])
    }

    func testLegacyRowWithoutCreatedAt_isSentWithSendTime() async throws {
        savePostIdentify(userId: "uid-queue-ts-legacy")
        saveTrack(DitoEvent(action: "legacy_no_created_at"))
        await waitUntil { self.queueCount() == 1 }

        let mock = MockMobileIngestClient()
        let sendStart = floorToSecond(Date())
        await DitoRetry(client: mock).runLoadOffline()

        let timestamp = try XCTUnwrap(trackActivities(mock.allActivityRequests).first).timestamp.date
        XCTAssertGreaterThanOrEqual(timestamp, sendStart)
        XCTAssertLessThanOrEqual(timestamp, Date())
    }

    // MARK: - receive-ios-notification

    private func receiveQueue() -> [DitoNotificationReceiveRow] {
        DitoNotificationOffline().getNotificationReceive
    }

    private func receiveTimestamps(_ requests: [Mobileingest_V1_Request]) -> [Date] {
        trackActivities(requests).compactMap { activity in
            guard let oneOf = activity.activity, case .trackPushReceipt = oneOf else { return nil }
            return activity.timestamp.date
        }
    }

    private let receiveUserInfo: [AnyHashable: Any] = [
        "user_id": "uid-queue-ts-receive",
        "notification": "notif-queue-ts",
        "log_id": "log-queue-ts",
        "notification_name": "queue-ts",
    ]

    func testFailedReceive_isResentWithArrivalTime() async throws {
        let failing = MockMobileIngestClient()
        failing.shouldSucceed = false
        Dito.testNotificationReceivedIngestClient = failing

        let before = floorToSecond(Date())
        await Dito.awaitNotificationReceivedDelivery(userInfo: receiveUserInfo, token: "fcm-queue-ts")
        let after = Date()

        let row = try XCTUnwrap(receiveQueue().first)
        let pending = try XCTUnwrap(row.json?.convertToObject(type: DitoNotificationReceivePending.self))
        XCTAssertNotNil(pending.receivedAt)

        // Resending later than a second after arrival is what tells arrival time from resend time.
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let mock = MockMobileIngestClient()
        Dito.testNotificationReceivedIngestClient = mock
        await DitoRetry(client: mock).runLoadOffline()

        XCTAssertTrue(receiveQueue().isEmpty)
        let timestamp = try XCTUnwrap(receiveTimestamps(mock.allActivityRequests).first)
        XCTAssertGreaterThanOrEqual(timestamp, before)
        XCTAssertLessThanOrEqual(timestamp, after)
    }

    func testLegacyReceiveRowWithoutReceivedAt_isSentWithSendTime() async throws {
        DitoNotificationOffline().notificationReceive(DitoNotificationReceivePending(
            userId: "uid-queue-ts-receive-legacy",
            token: "fcm-queue-ts-legacy",
            notification: "notif-queue-ts-legacy",
            logId: "log-queue-ts-legacy",
            notificationName: "queue-ts-legacy"
        ))
        let row = try XCTUnwrap(receiveQueue().first)
        let legacy = try XCTUnwrap(row.json?.convertToObject(type: DitoNotificationReceivePending.self))
        XCTAssertNil(legacy.receivedAt)

        let mock = MockMobileIngestClient()
        Dito.testNotificationReceivedIngestClient = mock
        let sendStart = floorToSecond(Date())
        await DitoRetry(client: mock).runLoadOffline()

        let timestamp = try XCTUnwrap(receiveTimestamps(mock.allActivityRequests).first)
        XCTAssertGreaterThanOrEqual(timestamp, sendStart)
        XCTAssertLessThanOrEqual(timestamp, Date())
    }

    // MARK: - Foreground

    private func drainMainQueue() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { cont.resume() }
        }
    }

    func testWillEnterForegroundNotification_flushesQueue() async throws {
        let client = MockMobileIngestClient()
        Dito.testIdentifyTrackIngestClient = client
        Dito.invalidateRetryCacheForTests()
        Dito.setReachabilityConnectionOverrideForTests(.wifi)

        // configure() runs on every receive; called twice, the observer must still be registered.
        Dito.shared.configure()
        Dito.shared.configure()
        await drainMainQueue()
        // Only the foreground observer may flush here, not a reachability event.
        NotificationCenter.default.removeObserver(Dito.shared, name: .reachabilityChanged, object: nil)

        savePostIdentify(userId: "uid-queue-ts-foreground")
        saveTrack(DitoEvent(action: "foreground_evt"))
        await waitUntil { self.queueCount() == 1 }

        await MainActor.run {
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        }

        await waitUntil { self.queueCount() == 0 }
        XCTAssertEqual(sentEvents(client.allActivityRequests), ["foreground_evt"])
    }

    func testWillEnterForeground_offline_keepsQueueWithoutSpendingRetry() async throws {
        let client = MockMobileIngestClient()
        Dito.testIdentifyTrackIngestClient = client
        Dito.invalidateRetryCacheForTests()
        Dito.setReachabilityConnectionOverrideForTests(.unavailable)

        savePostIdentify(userId: "uid-queue-ts-foreground-offline")
        saveTrack(DitoEvent(action: "foreground_offline_evt"))
        await waitUntil { self.queueCount() == 1 }

        await MainActor.run {
            Dito.shared.applicationWillEnterForeground(
                Notification(name: UIApplication.willEnterForegroundNotification)
            )
        }
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(client.activityCallCount, 0)
        XCTAssertEqual(DitoTrackDataManager().fetchOfflinePersistedTracks().first?.retry, 1)
    }

    // MARK: - Reachability

    func testReconnect_firstPassFails_delayedPassWaitsBackoffThenFlushesQueue() async throws {
        Dito.reconnectRetryDelay = 0
        let scheduled = captureScheduledPasses()
        DitoRetry.now = { 5_000_000 }
        DitoRetry.isOnline = { true }
        let client = FailsFirstCallClient()
        Dito.testIdentifyTrackIngestClient = client
        Dito.invalidateRetryCacheForTests()

        savePostIdentify(userId: "uid-queue-ts-reconnect")
        saveTrack(DitoEvent(action: "reconnect_evt"))
        await waitUntil { self.queueCount() == 1 }

        await MainActor.run {
            Dito.setReachabilityConnectionOverrideForTests(.wifi)
            Dito.shared.reachabilityChanged(Notification(name: .reachabilityChanged))
        }

        await waitUntil { scheduled.all.count == 1 }
        XCTAssertEqual(client.recorder.activityCallCount, 1, "a passada de +5s respeita a janela")
        XCTAssertEqual(firstRowRetry(), 2)

        DitoRetry.now = { 5_000_000 + DitoRetry.failureBackoff + 1 }
        try XCTUnwrap(scheduled.all.first).work.perform()
        await waitUntil { self.queueCount() == 0 }
        XCTAssertEqual(sentEvents(client.recorder.allActivityRequests), ["reconnect_evt", "reconnect_evt"])
    }
}

private final class ScheduledPasses: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [(delay: TimeInterval, work: DispatchWorkItem)] = []

    func add(_ delay: TimeInterval, _ work: DispatchWorkItem) {
        lock.lock()
        items.append((delay: delay, work: work))
        lock.unlock()
    }

    var all: [(delay: TimeInterval, work: DispatchWorkItem)] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }
}

/// Holds every call until `open()`, then fails it.
final class GatedFailingClient: MobileIngestClientProtocol, @unchecked Sendable {
    let recorder = MockMobileIngestClient()
    private let lock = NSLock()
    private var isOpen = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func activity(_ request: Mobileingest_V1_Request) async throws -> Mobileingest_V1_Response {
        _ = try await recorder.activity(request)
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            lock.lock()
            if isOpen {
                lock.unlock()
                cont.resume()
            } else {
                waiting.append(cont)
                lock.unlock()
            }
        }
        throw MobileIngestError(message: "falha segurada")
    }

    func open() {
        lock.lock()
        isOpen = true
        let held = waiting
        waiting = []
        lock.unlock()
        held.forEach { $0.resume() }
    }
}

private final class FailsFirstCallClient: MobileIngestClientProtocol, @unchecked Sendable {
    let recorder = MockMobileIngestClient()

    func activity(_ request: Mobileingest_V1_Request) async throws -> Mobileingest_V1_Response {
        let isFirst = recorder.activityCallCount == 0
        _ = try await recorder.activity(request)
        if isFirst {
            throw MobileIngestError(message: "network not ready yet")
        }
        return Mobileingest_V1_Response()
    }
}
#endif
