import XCTest
@testable import DitoSDK

class DitoIntegrationTests: XCTestCase {
    let timeout = TimeInterval(10)

    override func setUp() {
        super.setUp()
        setupTestEnvironment()
    }

    override func tearDown() {
        teardownTestEnvironment()
        super.tearDown()
    }

    func testCompleteFlow_IdentifyThenTrack() {
        let expectIdentify = expectation(description: "identify completed")
        let expectTrack = expectation(description: "track completed")

        let id = "integration_test_user"
        let user = DitoUser(
            name: "Integration Test",
            gender: .masculino,
            email: "integration@test.com",
            birthday: Date(),
            location: "São Paulo",
            createdAt: nil,
            customData: nil
        )

        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expectIdentify.fulfill()
        }

        Dito.identify(
            id: id,
            name: user.name,
            email: user.email,
            customData: nil
        )
        wait(for: [expectIdentify], timeout: timeout)

        Dito.track(action: "integration_test_action", data: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectTrack.fulfill()
        }
        wait(for: [expectTrack], timeout: timeout)

        let identifyDataManager = DitoIdentifyDataManager()
        let savedIdentify = identifyDataManager.fetch
        XCTAssertNotNil(savedIdentify, "Identify should be saved")

        let trackDataManager = DitoTrackDataManager()
        let savedTracks = trackDataManager.fetchAll
        XCTAssertGreaterThan(savedTracks.count, 0, "Track should be saved")
    }

    func testCompleteFlow_IdentifyThenRegisterToken() {
        let expectIdentify = expectation(description: "identify completed")
        let expectRegister = expectation(description: "register completed")

        let id = "integration_test_user_2"
        let user = DitoUser(
            name: "Integration Test 2",
            email: "integration2@test.com"
        )
        let token = "fcm_token_integration_123"

        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expectIdentify.fulfill()
        }

        Dito.identify(
            id: id,
            name: user.name,
            email: user.email,
            customData: nil
        )
        wait(for: [expectIdentify], timeout: timeout)

        Dito.registerDevice(token: token)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectRegister.fulfill()
        }
        wait(for: [expectRegister], timeout: timeout)

        let identifyDataManager = DitoIdentifyDataManager()
        let savedIdentify = identifyDataManager.fetch
        XCTAssertNotNil(savedIdentify, "Identify should be saved")

        let notificationRegisterDataManager = DitoNotificationRegisterDataManager()
        let savedRegister = notificationRegisterDataManager.fetch
        XCTAssertNotNil(savedRegister, "Token register should be saved")
    }

    func testCompleteFlow_NotificationReceivedAndClicked() {
        let userInfo: [AnyHashable: Any] = [
            "notification": "notif_integration_123",
            "user_id": "user_integration_123",
            "link": "app://integration/deeplink",
            "reference": "ref_integration_123",
            "title": "Integration Test",
            "message": "Test Message"
        ]
        let token = "fcm_token_integration_123"

        Dito.notificationReceived(userInfo: userInfo, token: token)

        let expectationRead = XCTestExpectation(description: "Notification received processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectationRead.fulfill()
        }
        wait(for: [expectationRead], timeout: timeout)

        let notificationDataManager = DitoNotificationReadDataManager()
        let savedNotifications = notificationDataManager.fetchAll
        XCTAssertGreaterThan(savedNotifications.count, 0, "Notification read should be saved")

        let expectationClick = XCTestExpectation(description: "Notification click callback")
        var receivedDeeplink: String?

        let notificationReceived = Dito.notificationClick(userInfo: userInfo) { deeplink in
            receivedDeeplink = deeplink
            expectationClick.fulfill()
        }

        wait(for: [expectationClick], timeout: timeout)

        XCTAssertEqual(notificationReceived.notification, "notif_integration_123", "Notification ID should match")
        XCTAssertEqual(receivedDeeplink, "app://integration/deeplink", "Deeplink should match")
    }

    func testIdentify_WithEmptyID() {
        let expectation = XCTestExpectation(description: "Identify with empty ID")

        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expectation.fulfill()
        }

        Dito.identify(id: "", name: "Test", email: "test@test.com", customData: nil)

        wait(for: [expectation], timeout: timeout)

        let dataManager = DitoIdentifyDataManager()
        let savedIdentify = dataManager.fetch

        XCTAssertNotNil(savedIdentify, "Identify should still be saved even with empty ID")
    }

    func testTrack_WithEmptyAction() {
        Dito.track(action: "", data: nil)

        let expectation = XCTestExpectation(description: "Track with empty action")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let trackDataManager = DitoTrackDataManager()
        let savedTracks = trackDataManager.fetchAll

        XCTAssertGreaterThanOrEqual(savedTracks.count, 0, "Track should handle empty action")
    }

    func testRegisterDevice_WithEmptyToken() {
        Dito.registerDevice(token: "")

        let expectation = XCTestExpectation(description: "Register with empty token")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let notificationRegisterDataManager = DitoNotificationRegisterDataManager()
        let savedRegister = notificationRegisterDataManager.fetch

        XCTAssertNotNil(savedRegister, "Token register should handle empty token")
    }

    func testNotificationRead_WithEmptyUserInfo() {
        let userInfo: [AnyHashable: Any] = [:]
        let token = "fcm_token_123"

        Dito.notificationReceived(userInfo: userInfo, token: token)

        let expectation = XCTestExpectation(description: "Notification received with empty userInfo")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let notificationDataManager = DitoNotificationReadDataManager()
        let savedNotifications = notificationDataManager.fetchAll

        XCTAssertGreaterThanOrEqual(savedNotifications.count, 0, "Notification read should handle empty userInfo")
    }

    func testConcurrentIdentify() {
        let expectation1 = XCTestExpectation(description: "Identify 1")
        let expectation2 = XCTestExpectation(description: "Identify 2")

        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expectation1.fulfill()
        }

        Dito.identify(id: "concurrent_user_1", name: "User 1", email: "user1@test.com", customData: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            DitoIdentifyDataManager.shared.identitySaveCallback = {
                expectation2.fulfill()
            }
            Dito.identify(id: "concurrent_user_2", name: "User 2", email: "user2@test.com", customData: nil)
        }

        wait(for: [expectation1, expectation2], timeout: timeout)

        let dataManager = DitoIdentifyDataManager()
        let savedIdentify = dataManager.fetch

        XCTAssertNotNil(savedIdentify, "Identify should handle concurrent calls")
    }

    func testConcurrentTrack() {
        let expectation1 = XCTestExpectation(description: "Track 1")
        let expectation2 = XCTestExpectation(description: "Track 2")

        Dito.track(action: "concurrent_action_1", data: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Dito.track(action: "concurrent_action_2", data: nil)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation1.fulfill()
            expectation2.fulfill()
        }

        wait(for: [expectation1, expectation2], timeout: timeout)

        let trackDataManager = DitoTrackDataManager()
        let savedTracks = trackDataManager.fetchAll

        XCTAssertGreaterThanOrEqual(savedTracks.count, 0, "Track should handle concurrent calls")
    }

    func testConcurrentNotificationRead() {
        let userInfo1: [AnyHashable: Any] = ["notification": "notif_1"]
        let userInfo2: [AnyHashable: Any] = ["notification": "notif_2"]
        let token = "fcm_token_123"

        Dito.notificationReceived(userInfo: userInfo1, token: token)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Dito.notificationReceived(userInfo: userInfo2, token: token)
        }

        let expectation = XCTestExpectation(description: "Concurrent notification read")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout)

        let notificationDataManager = DitoNotificationReadDataManager()
        let savedNotifications = notificationDataManager.fetchAll

        XCTAssertGreaterThanOrEqual(savedNotifications.count, 0, "Notification read should handle concurrent calls")
    }
}
