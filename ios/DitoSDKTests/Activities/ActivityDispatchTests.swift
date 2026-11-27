import Security
import XCTest
@testable import DitoSDK

final class ActivityDispatchTests: XCTestCase {

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
        #if DEBUG
        Dito.testNotificationReceivedIngestClient = nil
        #endif
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

    func testMockMobileIngestClient_recordsActivityCallsAndLastRequest() async throws {
        let mock = MockMobileIngestClient()
        let first = Mobileingest_V1_Request()
        let second = Mobileingest_V1_Request()

        _ = try await mock.activity(first)
        _ = try await mock.activity(second)

        XCTAssertEqual(mock.activityCallCount, 2)
        XCTAssertEqual(mock.allActivityRequests.count, 2)
        XCTAssertEqual(mock.lastActivityRequest, second)

        mock.reset()
        XCTAssertEqual(mock.activityCallCount, 0)
        XCTAssertNil(mock.lastActivityRequest)
        XCTAssertTrue(mock.allActivityRequests.isEmpty)
    }

    func testMockMobileIngestClient_throwsWhenConfigured() async {
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = false
        mock.errorToThrow = MobileIngestError(message: "expected")

        do {
            _ = try await mock.activity(Mobileingest_V1_Request())
            XCTFail("expected throw")
        } catch let e as MobileIngestError {
            XCTAssertEqual(e.message, "expected")
        } catch {
            XCTFail("wrong error \(error)")
        }

        XCTAssertEqual(mock.activityCallCount, 1)
    }

    func testIdentify_sendsSingleIdentifyActivity() async throws {
        let mock = MockMobileIngestClient()
        let sut = DitoIdentify(retry: Dito.shared.retry, client: mock)
        let userId = "uid-identify-dispatch-1"
        let user = DitoUser(name: "Unit", email: "unit@example.com", customData: nil)
        sut.identify(id: userId, data: user)
        await waitForActivityCalls(mock, count: 1)
        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, userId)
        XCTAssertEqual(req.activities.count, 1)
        let a = req.activities[0]
        XCTAssertEqual(a.type, .activityIdentify)
        switch a.activity {
        case .identify(let info)?:
            XCTAssertEqual(info.email, "unit@example.com")
        default:
            XCTFail("expected identify oneof, got \(String(describing: a.activity))")
        }
    }

    func testTrackOnline_sendsTrackActivityWhenUserIdentified() async throws {
        let identifyMock = MockMobileIngestClient()
        let identify = DitoIdentify(retry: Dito.shared.retry, client: identifyMock)
        let userId = "uid-track-dispatch-1"
        identify.identify(id: userId, data: DitoUser(email: "track@example.com"))
        await waitForActivityCalls(identifyMock, count: 1)

        let trackMock = MockMobileIngestClient()
        let track = DitoTrack(client: trackMock)
        track.track(data: DitoEvent(action: "button_tap", customData: nil))
        await waitForActivityCalls(trackMock, count: 1)

        let req = try XCTUnwrap(trackMock.lastActivityRequest)
        XCTAssertEqual(req.userID, userId)
        XCTAssertEqual(req.activities.count, 1)
        let a = req.activities[0]
        XCTAssertEqual(a.type, .activityTrack)
        switch a.activity {
        case .track(let t)?:
            XCTAssertEqual(t.event, "button_tap")
        default:
            XCTFail("expected track oneof, got \(String(describing: a.activity))")
        }
    }

    func testNotificationClick_sendsTrackPushClickActivity() async throws {
        let mock = MockMobileIngestClient()
        let sut = DitoNotification(client: mock)
        sut.notificationClick(notificationId: "nid-dispatch-1", identifier: "user-dispatch-1")
        await waitForActivityCalls(mock, count: 1)
        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, "user-dispatch-1")
        let a = try XCTUnwrap(req.activities.first)
        XCTAssertEqual(a.type, .activityTrack)
        switch a.activity {
        case .trackPushClick(let click)?:
            XCTAssertEqual(click.notification.notificationID, "nid-dispatch-1")
            XCTAssertEqual(click.notification.identifier, "user-dispatch-1")
        default:
            XCTFail("expected trackPushClick oneof, got \(String(describing: a.activity))")
        }
    }

    func testNotificationClick_sendsDispatchIdNameAndMobileChannel() async throws {
        let mock = MockMobileIngestClient()
        let sut = DitoNotification(client: mock)
        sut.notificationClick(
            notificationId: "nid-dispatch-2",
            identifier: "user-dispatch-2",
            logId: "log-dispatch-2",
            notificationName: "Campanha 2"
        )
        await waitForActivityCalls(mock, count: 1)
        let a = try XCTUnwrap(mock.lastActivityRequest?.activities.first)
        guard case .trackPushClick(let click)? = a.activity else {
            return XCTFail("expected trackPushClick oneof, got \(String(describing: a.activity))")
        }
        XCTAssertEqual(click.notification.dispatchID, "log-dispatch-2")
        XCTAssertEqual(click.notification.name, "Campanha 2")
        XCTAssertEqual(click.notification.channel, "mobile")
    }

    func testNotificationClick_withoutLogId_stillSendsMobileChannel() async throws {
        let mock = MockMobileIngestClient()
        let sut = DitoNotification(client: mock)
        sut.notificationClick(notificationId: "nid-dispatch-3", identifier: "user-dispatch-3")
        await waitForActivityCalls(mock, count: 1)
        let a = try XCTUnwrap(mock.lastActivityRequest?.activities.first)
        guard case .trackPushClick(let click)? = a.activity else {
            return XCTFail("expected trackPushClick oneof, got \(String(describing: a.activity))")
        }
        XCTAssertEqual(click.notification.dispatchID, "")
        XCTAssertEqual(click.notification.name, "")
        XCTAssertEqual(click.notification.channel, "mobile")
    }

    func testNotificationClick_ingestFails_queuesLogIdNameAndChannel() async throws {
        let readQueue = DitoNotificationReadDataManager()
        readQueue.fetchAll.forEach { _ = readQueue.delete(with: $0.id) }
        addTeardownBlock {
            readQueue.fetchAll.forEach { _ = readQueue.delete(with: $0.id) }
        }
        func ownRequests() -> [DitoNotificationOpenRequest] {
            readQueue.fetchAll
                .compactMap { $0.json?.convertToObject(type: DitoNotificationOpenRequest.self) }
                .filter { $0.data.notification == "nid-dispatch-4" }
        }
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = false
        let sut = DitoNotification(client: mock, onSent: {})
        sut.notificationClick(
            notificationId: "nid-dispatch-4",
            identifier: "user-dispatch-4",
            logId: "log-dispatch-4",
            notificationName: "Campanha 4"
        )
        let deadline = Date().addingTimeInterval(10)
        while ownRequests().isEmpty, Date() < deadline {
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        let queued = try XCTUnwrap(ownRequests().first)
        XCTAssertEqual(queued.data.logId, "log-dispatch-4")
        XCTAssertEqual(queued.data.notificationName, "Campanha 4")
        XCTAssertEqual(queued.data.channel, "mobile")
    }

    #if DEBUG
    private func trackAndWait(_ sut: DitoTrack, action: String) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sut.track(data: DitoEvent(action: action, customData: nil)) { _ in cont.resume() }
        }
    }

    private func waitForTrackRows(_ count: Int, timeout: TimeInterval = 5) async {
        let deadline = Date().addingTimeInterval(timeout)
        while DitoTrackDataManager().fetchOfflinePersistedTracks().count < count, Date() < deadline {
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTAssertEqual(DitoTrackDataManager().fetchOfflinePersistedTracks().count, count)
    }

    func testAnonymousIdentify_onlyFirstAnonymousCallCarriesIt() async throws {
        DeviceIdProvider.setForTests("device-anon-identify-1")
        let mock = MockMobileIngestClient()
        let sut = DitoTrack(client: mock)

        await trackAndWait(sut, action: "anon_first")
        await trackAndWait(sut, action: "anon_second")

        XCTAssertEqual(mock.activityCallCount, 2)
        let first = mock.allActivityRequests[0]
        XCTAssertEqual(first.userID, "")
        XCTAssertEqual(first.activities.map(\.type), [.activityIdentify, .activityTrack])
        guard let oneOf = first.activities[0].activity, case .identify(let identify) = oneOf else {
            XCTFail("expected identify oneof, got \(String(describing: first.activities[0].activity))")
            return
        }
        XCTAssertEqual(Set(identify.customData.keys), Set(["device_model", "sdk_version"]))
        XCTAssertEqual(identify.customData["device_model"]?.single.stringValue, first.device.deviceModel)
        XCTAssertEqual(identify.customData["sdk_version"]?.single.stringValue, first.sdk.version)
        XCTAssertEqual(identify.name, "")
        XCTAssertEqual(identify.email, "")

        let second = mock.allActivityRequests[1]
        XCTAssertEqual(second.userID, "")
        XCTAssertEqual(second.activities.map(\.type), [.activityTrack])
        XCTAssertEqual(
            UserDefaults.anonymousIdentifyMark,
            ["device_id": "device-anon-identify-1", "sdk_version": first.sdk.version]
        )
    }

    func testAnonymousIdentify_failedCallDoesNotSaveMark_nextCallCarriesIt() async throws {
        DeviceIdProvider.setForTests("device-anon-identify-2")
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = false
        let sut = DitoTrack(client: mock)

        await trackAndWait(sut, action: "anon_fail")
        await waitForTrackRows(1)
        XCTAssertNil(UserDefaults.anonymousIdentifyMark)

        mock.shouldSucceed = true
        await trackAndWait(sut, action: "anon_after_fail")

        XCTAssertEqual(mock.activityCallCount, 2)
        XCTAssertEqual(mock.allActivityRequests[0].activities.first?.type, .activityIdentify)
        XCTAssertEqual(mock.allActivityRequests[1].activities.map(\.type), [.activityIdentify, .activityTrack])
        XCTAssertNotNil(UserDefaults.anonymousIdentifyMark)
    }

    func testAnonymousIdentify_markFromOtherSdkVersionOrWithoutVersion_sendsAgainAndSavesNewMark() async throws {
        let deviceId = "device-anon-identify-3"
        DeviceIdProvider.setForTests(deviceId)
        let mock = MockMobileIngestClient()
        let sut = DitoTrack(client: mock)

        UserDefaults.anonymousIdentifyMark = ["device_id": deviceId, "sdk_version": "0.0.0-old"]
        await trackAndWait(sut, action: "anon_new_version")
        let currentVersion = try XCTUnwrap(mock.lastActivityRequest).sdk.version
        XCTAssertEqual(mock.lastActivityRequest?.activities.first?.type, .activityIdentify)
        XCTAssertEqual(UserDefaults.anonymousIdentifyMark, ["device_id": deviceId, "sdk_version": currentVersion])

        UserDefaults.anonymousIdentifyMark = ["device_id": deviceId]
        await trackAndWait(sut, action: "anon_mark_without_version")
        XCTAssertEqual(mock.lastActivityRequest?.activities.first?.type, .activityIdentify)

        UserDefaults.anonymousIdentifyMark = ["device_id": "other-device", "sdk_version": currentVersion]
        await trackAndWait(sut, action: "anon_other_device")
        XCTAssertEqual(mock.lastActivityRequest?.activities.first?.type, .activityIdentify)
        XCTAssertEqual(UserDefaults.anonymousIdentifyMark, ["device_id": deviceId, "sdk_version": currentVersion])
    }

    func testAnonymousIdentify_notSentWhenLoggedIn() async throws {
        DeviceIdProvider.setForTests("device-anon-identify-4")
        let userId = "uid-anon-identify-logged"
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: nil, send: true))
        let mock = MockMobileIngestClient()

        await trackAndWait(DitoTrack(client: mock), action: "logged_evt")

        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, userId)
        XCTAssertEqual(req.activities.map(\.type), [.activityTrack])
        XCTAssertNil(UserDefaults.anonymousIdentifyMark)
    }

    func testAnonymousTrack_withoutDeviceId_isQueuedAsAnonymousWithoutCallingIngest() async throws {
        DeviceIdProvider.setForTests("")
        let mock = MockMobileIngestClient()

        await trackAndWait(DitoTrack(client: mock), action: "no_device_id_evt")
        await waitForTrackRows(1)

        XCTAssertEqual(mock.activityCallCount, 0)
        XCTAssertNil(UserDefaults.anonymousIdentifyMark)
        let rows = DitoTrackDataManager().fetchOfflinePersistedTracks()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.anonymous, true)
    }

    func testDeviceIdProvider_realKeychain_returnsSameNonEmptyValue() throws {
        DeviceIdProvider.resetForTests()
        let first = DeviceIdProvider.get()
        if first.isEmpty {
            throw XCTSkip("Keychain indisponível neste simulador (testes sem app host); estabilidade coberta pelos testes com Keychain simulado")
        }
        XCTAssertEqual(DeviceIdProvider.get(), first)
        XCTAssertEqual(DeviceIdProvider.get(), first)
    }

    private func stubKeychain(
        reads: [(OSStatus, String?)],
        add: OSStatus
    ) -> (readCount: () -> Int, addCount: () -> Int) {
        var readCount = 0
        var addCount = 0
        DeviceIdProvider.copyMatching = { _, result in
            let (status, value) = reads[min(readCount, reads.count - 1)]
            readCount += 1
            if let value { result?.pointee = Data(value.utf8) as CFData }
            return status
        }
        DeviceIdProvider.addItem = { _, _ in
            addCount += 1
            return add
        }
        return ({ readCount }, { addCount })
    }

    func testDeviceIdProvider_readSucceeds_returnsStoredIdWithoutAdding() {
        let counts = stubKeychain(reads: [(errSecSuccess, "stored-id")], add: errSecSuccess)
        XCTAssertEqual(DeviceIdProvider.get(), "stored-id")
        XCTAssertEqual(DeviceIdProvider.get(), "stored-id")
        XCTAssertEqual(counts.readCount(), 1, "o valor fica em memória depois da primeira leitura")
        XCTAssertEqual(counts.addCount(), 0)
    }

    func testDeviceIdProvider_notFoundAndAddSucceeds_returnsStableGeneratedId() {
        let counts = stubKeychain(reads: [(errSecItemNotFound, nil)], add: errSecSuccess)
        let first = DeviceIdProvider.get()
        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(DeviceIdProvider.get(), first)
        XCTAssertEqual(counts.addCount(), 1)
    }

    func testDeviceIdProvider_notFoundAndAddReportsDuplicate_returnsReReadId() {
        let counts = stubKeychain(
            reads: [(errSecItemNotFound, nil), (errSecSuccess, "other-process-id")],
            add: errSecDuplicateItem
        )
        XCTAssertEqual(DeviceIdProvider.get(), "other-process-id")
        XCTAssertEqual(DeviceIdProvider.get(), "other-process-id")
        XCTAssertEqual(counts.readCount(), 2)
    }

    func testDeviceIdProvider_notFoundAndAddFails_returnsEmptyWithoutCaching() {
        let counts = stubKeychain(reads: [(errSecItemNotFound, nil)], add: errSecInteractionNotAllowed)
        XCTAssertEqual(DeviceIdProvider.get(), "")
        XCTAssertEqual(DeviceIdProvider.get(), "")
        XCTAssertEqual(counts.addCount(), 2, "sem cache, a próxima chamada tenta de novo")
    }

    func testDeviceIdProvider_unreadableKeychain_returnsEmptyWithoutGeneratingOrCaching() {
        let counts = stubKeychain(reads: [(errSecInteractionNotAllowed, nil)], add: errSecSuccess)
        XCTAssertEqual(DeviceIdProvider.get(), "")
        XCTAssertEqual(DeviceIdProvider.get(), "")
        XCTAssertEqual(counts.readCount(), 2)
        XCTAssertEqual(counts.addCount(), 0)
    }
    #endif

    #if DEBUG
    func testNotificationReceived_withUserId_sendsIdentifyAndPushReceiptActivities() async throws {
        let mock = MockMobileIngestClient()
        Dito.testNotificationReceivedIngestClient = mock
        addTeardownBlock {
            Dito.testNotificationReceivedIngestClient = nil
        }
        let uid = "uid-notif-received-1"
        let userInfo: [AnyHashable: Any] = [
            "user_id": uid,
            "notification": "notif-abc",
            "reference": "ref-abc",
            "log_id": "log-abc",
            "notification_name": "Campanha ABC",
            "title": "Hello",
            "message": "World",
            "link": "https://example.com",
        ]
        Dito.notificationReceived(userInfo: userInfo, token: "fcm-token-test")
        await waitForActivityCalls(mock, count: 1)
        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, uid)
        XCTAssertEqual(req.activities.count, 2)
        XCTAssertEqual(req.activities[0].type, .activityIdentify)
        XCTAssertEqual(req.activities[1].type, .activityTrack)
        switch req.activities[1].activity {
        case .trackPushReceipt(let receipt)?:
            XCTAssertEqual(receipt.notification.notificationID, "notif-abc")
            XCTAssertEqual(receipt.notification.dispatchID, "log-abc")
            XCTAssertEqual(receipt.notification.name, "Campanha ABC")
            XCTAssertEqual(receipt.notification.identifier, uid)
            XCTAssertEqual(receipt.notification.channel, "mobile")
            XCTAssertEqual(receipt.data["token"]?.single.stringValue, "fcm-token-test")
        default:
            XCTFail("expected trackPushReceipt, got \(String(describing: req.activities[1].activity))")
        }
    }
    #endif
}
