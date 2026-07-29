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

    #if DEBUG
    func testNotificationReceived_withUserId_sendsIdentifyAndTrackActivities() async throws {
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
        case .track(let track)?:
            XCTAssertEqual(track.event, "receive-ios-notification")
        default:
            XCTFail("expected track for receive-ios-notification, got \(String(describing: req.activities[1].activity))")
        }
    }
    #endif
}
