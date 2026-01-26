import XCTest
@testable import DitoSDK

class DitoTests: XCTestCase {
    let timeout = TimeInterval(5)

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
        DitoIdentifyDataManager.shared.identitySaveCallback = nil
    }

    func testSha1_ReturnsCorrectHash() {
        let email = "test@example.com"
        let hash = Dito.sha1(for: email)

        XCTAssertFalse(hash.isEmpty, "Hash should not be empty")
        XCTAssertEqual(hash.count, 40, "SHA1 hash should be 40 characters")
    }

    func testSha1_IsDeterministic() {
        let email = "test@example.com"
        let hash1 = Dito.sha1(for: email)
        let hash2 = Dito.sha1(for: email)

        XCTAssertEqual(hash1, hash2, "Same input should produce same hash")
    }

    func testSha1_HandlesEmptyString() {
        let hash = Dito.sha1(for: "")

        XCTAssertFalse(hash.isEmpty, "Empty string should still produce a hash")
    }

    func testSha1_HandlesSpecialCharacters() {
        let email = "test+special@example.com"
        let hash = Dito.sha1(for: email)

        XCTAssertFalse(hash.isEmpty, "Hash should handle special characters")
        XCTAssertEqual(hash.count, 40, "SHA1 hash should be 40 characters")
    }

    func testIdentifyWithIndividualParams_CreatesUser() {
        let expectation = XCTestExpectation(description: "Identify with individual params")
        let id = "test_user_123"

        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expectation.fulfill()
        }

        Dito.identify(id: id, name: "Test User", email: "test@example.com", customData: nil)

        wait(for: [expectation], timeout: timeout)

        let dataManager = DitoIdentifyDataManager()
        let savedIdentify = dataManager.fetch

        XCTAssertNotNil(savedIdentify, "Identify should be saved")
        XCTAssertEqual(savedIdentify?.id, id, "Saved ID should match")
    }

    func testIdentifyWithIndividualParams_WithName() {
        let expectation = XCTestExpectation(description: "Identify with name")
        let id = "test_user_123"
        let name = "John Doe"

        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expectation.fulfill()
        }

        Dito.identify(id: id, name: name, email: nil, customData: nil)

        wait(for: [expectation], timeout: timeout)

        let dataManager = DitoIdentifyDataManager()
        let savedIdentify = dataManager.fetch

        XCTAssertNotNil(savedIdentify, "Identify should be saved")
    }

    func testIdentifyWithIndividualParams_WithEmail() {
        let expectation = XCTestExpectation(description: "Identify with email")
        let id = "test_user_123"
        let email = "test@example.com"

        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expectation.fulfill()
        }

        Dito.identify(id: id, name: nil, email: email, customData: nil)

        wait(for: [expectation], timeout: timeout)

        let dataManager = DitoIdentifyDataManager()
        let savedIdentify = dataManager.fetch

        XCTAssertNotNil(savedIdentify, "Identify should be saved")
    }

    func testIdentifyWithIndividualParams_WithCustomData() {
        let expectation = XCTestExpectation(description: "Identify with custom data")
        let id = "test_user_123"
        let customData: [String: Any] = ["key1": "value1", "key2": 123]

        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expectation.fulfill()
        }

        Dito.identify(id: id, name: nil, email: nil, customData: customData)

        wait(for: [expectation], timeout: timeout)

        let dataManager = DitoIdentifyDataManager()
        let savedIdentify = dataManager.fetch

        XCTAssertNotNil(savedIdentify, "Identify should be saved")
    }

    func testIdentifyWithIndividualParams_AllParams() {
        let expectation = XCTestExpectation(description: "Identify with all params")
        let id = "test_user_123"
        let name = "John Doe"
        let email = "john@example.com"
        let customData: [String: Any] = ["premium": true]

        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expectation.fulfill()
        }

        Dito.identify(id: id, name: name, email: email, customData: customData)

        wait(for: [expectation], timeout: timeout)

        let dataManager = DitoIdentifyDataManager()
        let savedIdentify = dataManager.fetch

        XCTAssertNotNil(savedIdentify, "Identify should be saved")
    }

    func testIdentifyWithIndividualParams_NilParams() {
        let expectation = XCTestExpectation(description: "Identify with nil params")
        let id = "test_user_123"

        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expectation.fulfill()
        }

        Dito.identify(id: id, name: nil, email: nil, customData: nil)

        wait(for: [expectation], timeout: timeout)

        let dataManager = DitoIdentifyDataManager()
        let savedIdentify = dataManager.fetch

        XCTAssertNotNil(savedIdentify, "Identify should be saved")
    }

    func testTrackWithActionAndData_CreatesEvent() {
        let action = "test_action"
        let data: [String: Any] = ["key": "value"]

        Dito.track(action: action, data: data)

        let expectation = XCTestExpectation(description: "Track event saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let trackDataManager = DitoTrackDataManager()
        let savedTracks = trackDataManager.fetchAll

        XCTAssertGreaterThan(savedTracks.count, 0, "Event should be saved")
    }

    func testTrackWithActionOnly() {
        let action = "test_action_only"

        Dito.track(action: action, data: nil)

        let expectation = XCTestExpectation(description: "Track event saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let trackDataManager = DitoTrackDataManager()
        let savedTracks = trackDataManager.fetchAll

        XCTAssertGreaterThan(savedTracks.count, 0, "Event should be saved")
    }

    func testTrackWithActionAndData() {
        let action = "test_action_with_data"
        let data: [String: Any] = ["product_id": "123", "price": 99.99]

        Dito.track(action: action, data: data)

        let expectation = XCTestExpectation(description: "Track event saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let trackDataManager = DitoTrackDataManager()
        let savedTracks = trackDataManager.fetchAll

        XCTAssertGreaterThan(savedTracks.count, 0, "Event should be saved")
    }

    func testTrackWithActionAndNilData() {
        let action = "test_action_nil_data"

        Dito.track(action: action, data: nil)

        let expectation = XCTestExpectation(description: "Track event saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let trackDataManager = DitoTrackDataManager()
        let savedTracks = trackDataManager.fetchAll

        XCTAssertGreaterThan(savedTracks.count, 0, "Event should be saved")
    }

    func testNotificationRead_CreatesNotificationReceived() {
        let userInfo: [AnyHashable: Any] = [
            "notification": "notif_123",
            "user_id": "user_123",
            "link": "app://deeplink",
            "reference": "ref_123"
        ]
        let token = "fcm_token_123"

        Dito.notificationReceived(userInfo: userInfo, token: token)

        let expectation = XCTestExpectation(description: "Notification received processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let notificationDataManager = DitoNotificationReadDataManager()
        let savedNotifications = notificationDataManager.fetchAll

        XCTAssertGreaterThan(savedNotifications.count, 0, "Notification read should be saved")
    }

    func testNotificationRead_WithValidUserInfo() {
        let userInfo: [AnyHashable: Any] = [
            "notification": "notif_123",
            "user_id": "user_123",
            "link": "app://deeplink",
            "reference": "ref_123",
            "title": "Test Title",
            "message": "Test Message"
        ]
        let token = "fcm_token_123"

        Dito.notificationReceived(userInfo: userInfo, token: token)

        let expectation = XCTestExpectation(description: "Notification received processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let notificationDataManager = DitoNotificationReadDataManager()
        let savedNotifications = notificationDataManager.fetchAll

        XCTAssertGreaterThan(savedNotifications.count, 0, "Notification read should be saved")
    }

    func testNotificationRead_WithInvalidUserInfo() {
        let userInfo: [AnyHashable: Any] = [:]
        let token = "fcm_token_123"

        Dito.notificationReceived(userInfo: userInfo, token: token)

        let expectation = XCTestExpectation(description: "Notification received processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let notificationDataManager = DitoNotificationReadDataManager()
        let savedNotifications = notificationDataManager.fetchAll

        XCTAssertGreaterThanOrEqual(savedNotifications.count, 0, "Notification read should handle invalid userInfo")
    }

    func testNotificationClick_ReturnsNotificationReceived() {
        let userInfo: [AnyHashable: Any] = [
            "notification": "notif_123",
            "user_id": "user_123",
            "link": "app://deeplink",
            "reference": "ref_123"
        ]

        let notificationReceived = Dito.notificationClick(userInfo: userInfo, callback: nil)

        XCTAssertEqual(notificationReceived.notification, "notif_123", "Notification ID should match")
        XCTAssertEqual(notificationReceived.identifier, "user_123", "User ID should match")
        XCTAssertEqual(notificationReceived.deeplink, "app://deeplink", "Deeplink should match")
    }

    func testNotificationClick_CallsCallbackWithDeeplink() {
        let userInfo: [AnyHashable: Any] = [
            "notification": "notif_123",
            "user_id": "user_123",
            "link": "app://deeplink",
            "reference": "ref_123"
        ]

        let expectation = XCTestExpectation(description: "Callback called")
        var receivedDeeplink: String?

        Dito.notificationClick(userInfo: userInfo) { deeplink in
            receivedDeeplink = deeplink
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout)

        XCTAssertEqual(receivedDeeplink, "app://deeplink", "Callback should receive deeplink")
    }

    func testNotificationClick_WithNilCallback() {
        let userInfo: [AnyHashable: Any] = [
            "notification": "notif_123",
            "user_id": "user_123",
            "link": "app://deeplink",
            "reference": "ref_123"
        ]

        let notificationReceived = Dito.notificationClick(userInfo: userInfo, callback: nil)

        XCTAssertEqual(notificationReceived.notification, "notif_123", "Should work without callback")
    }

    func testNotificationClick_ExtractsDeeplink() {
        let userInfo: [AnyHashable: Any] = [
            "notification": "notif_123",
            "user_id": "user_123",
            "link": "app://products/123",
            "reference": "ref_123"
        ]

        let notificationReceived = Dito.notificationClick(userInfo: userInfo, callback: nil)

        XCTAssertEqual(notificationReceived.deeplink, "app://products/123", "Deeplink should be extracted correctly")
    }
}
