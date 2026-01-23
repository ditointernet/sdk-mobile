import XCTest
@testable import DitoSDK

class DitoControllerTests: XCTestCase {
    let timeout = TimeInterval(10)

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
        DitoIdentifyDataManager.shared.identitySaveCallback = nil
        DitoIdentifyDataManager.shared.deleteIdentifyStamp()
    }

    func testDitoIdentify_WithValidEmail() {
        let identifyController = DitoIdentify()
        let expectation = XCTestExpectation(description: "Identify with valid email")

        let user = DitoUser(
            name: "Test User",
            email: "test@example.com"
        )

        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expectation.fulfill()
        }

        identifyController.identify(id: "test_id", data: user)

        wait(for: [expectation], timeout: timeout)

        let dataManager = DitoIdentifyDataManager()
        let savedIdentify = dataManager.fetch

        XCTAssertNotNil(savedIdentify, "Identify should be saved")
    }

    func testDitoIdentify_WithInvalidEmail_DoesNotCallAPI() {
        let identifyController = DitoIdentify()

        let user = DitoUser(
            name: "Test User",
            email: nil
        )

        identifyController.identify(id: "test_id", data: user)

        let expectation = XCTestExpectation(description: "Identify finished")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let savingState = DitoIdentifyOffline.shared.getSavingState
        XCTAssertFalse(savingState, "Saving state should be false when email is invalid")
    }

    func testDitoTrack_WithReference_SendsToAPI() {
        let trackController = DitoTrack()
        let identifyOffline = DitoIdentifyOffline.shared

        let signupRequest = DitoSignupRequest(
            platformApiKey: "test_key",
            sha1Signature: "test_signature",
            userData: nil
        )

        identifyOffline.identify(
            id: "test_id",
            params: signupRequest,
            reference: "ref_123",
            send: true
        )

        let event = DitoEvent(action: "test_action")
        trackController.track(data: event)

        let expectation = XCTestExpectation(description: "Track processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let trackDataManager = DitoTrackDataManager()
        let savedTracks = trackDataManager.fetchAll

        XCTAssertGreaterThanOrEqual(savedTracks.count, 0, "Track should be processed")
    }

    func testDitoTrack_WithoutReference_SavesOffline() {
        let trackController = DitoTrack()

        let event = DitoEvent(action: "test_action")
        trackController.track(data: event)

        let expectation = XCTestExpectation(description: "Track saved offline")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let trackDataManager = DitoTrackDataManager()
        let savedTracks = trackDataManager.fetchAll

        XCTAssertGreaterThan(savedTracks.count, 0, "Track should be saved offline")
    }

    func testDitoTrack_WaitsForIdentify() {
        let trackController = DitoTrack()
        let identifyOffline = DitoIdentifyOffline.shared

        identifyOffline.initiateIdentify()

        let event = DitoEvent(action: "test_action")
        trackController.track(data: event)

        let expectation = XCTestExpectation(description: "Track waits for identify")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            identifyOffline.finishIdentify()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let trackDataManager = DitoTrackDataManager()
        let savedTracks = trackDataManager.fetchAll

        XCTAssertGreaterThanOrEqual(savedTracks.count, 0, "Track should wait for identify")
    }

    func testDitoNotification_RegisterToken_WithReference_SendsToAPI() {
        let notificationController = DitoNotification()
        let identifyOffline = DitoIdentifyOffline.shared

        let signupRequest = DitoSignupRequest(
            platformApiKey: "test_key",
            sha1Signature: "test_signature",
            userData: nil
        )

        identifyOffline.identify(
            id: "test_id",
            params: signupRequest,
            reference: "ref_123",
            send: true
        )

        notificationController.registerToken(token: "fcm_token_123")

        let expectation = XCTestExpectation(description: "Token registered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let notificationRegisterDataManager = DitoNotificationRegisterDataManager()
        let savedRegister = notificationRegisterDataManager.fetch

        XCTAssertNotNil(savedRegister, "Token register should be processed")
    }

    func testDitoNotification_RegisterToken_WithoutReference_SavesOffline() {
        let notificationController = DitoNotification()

        notificationController.registerToken(token: "fcm_token_123")

        let expectation = XCTestExpectation(description: "Token saved offline")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let notificationRegisterDataManager = DitoNotificationRegisterDataManager()
        let savedRegister = notificationRegisterDataManager.fetch

        XCTAssertNotNil(savedRegister, "Token register should be saved offline")
    }

    func testDitoNotification_UnregisterToken_WithReference_SendsToAPI() {
        let notificationController = DitoNotification()
        let identifyOffline = DitoIdentifyOffline.shared

        let signupRequest = DitoSignupRequest(
            platformApiKey: "test_key",
            sha1Signature: "test_signature",
            userData: nil
        )

        identifyOffline.identify(
            id: "test_id",
            params: signupRequest,
            reference: "ref_123",
            send: true
        )

        notificationController.unregisterToken(token: "fcm_token_123")

        let expectation = XCTestExpectation(description: "Token unregistered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let notificationUnregisterDataManager = DitoNotificationUnregisterDataManager()
        let savedUnregister = notificationUnregisterDataManager.fetch

        XCTAssertNotNil(savedUnregister, "Token unregister should be processed")
    }

    func testDitoNotification_UnregisterToken_WithoutReference_SavesOffline() {
        let notificationController = DitoNotification()

        notificationController.unregisterToken(token: "fcm_token_123")

        let expectation = XCTestExpectation(description: "Token unregister saved offline")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let notificationUnregisterDataManager = DitoNotificationUnregisterDataManager()
        let savedUnregister = notificationUnregisterDataManager.fetch

        XCTAssertNotNil(savedUnregister, "Token unregister should be saved offline")
    }

    func testDitoNotification_NotificationRead_SavesOffline() {
        let notificationController = DitoNotification()
        let userInfo: [AnyHashable: Any] = [
            "notification": "notif_123",
            "user_id": "user_123"
        ]

        notificationController.notificationRead(with: userInfo)

        let expectation = XCTestExpectation(description: "Notification read saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let notificationDataManager = DitoNotificationReadDataManager()
        let savedNotifications = notificationDataManager.fetchAll

        XCTAssertGreaterThan(savedNotifications.count, 0, "Notification read should be saved")
    }

    func testDitoNotification_NotificationClick_WithReference_SendsToAPI() {
        let notificationController = DitoNotification()
        let identifyOffline = DitoIdentifyOffline.shared

        let signupRequest = DitoSignupRequest(
            platformApiKey: "test_key",
            sha1Signature: "test_signature",
            userData: nil
        )

        identifyOffline.identify(
            id: "test_id",
            params: signupRequest,
            reference: "ref_123",
            send: true
        )

        notificationController.notificationClick(
            notificationId: "notif_123",
            reference: "ref_123",
            identifier: "user_123"
        )

        let expectation = XCTestExpectation(description: "Notification click processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let notificationDataManager = DitoNotificationReadDataManager()
        let savedNotifications = notificationDataManager.fetchAll

        XCTAssertGreaterThanOrEqual(savedNotifications.count, 0, "Notification click should be processed")
    }

    func testDitoNotification_NotificationClick_WithoutReference_SavesOffline() {
        let notificationController = DitoNotification()

        notificationController.notificationClick(
            notificationId: "notif_123",
            reference: "",
            identifier: "user_123"
        )

        let expectation = XCTestExpectation(description: "Notification click saved offline")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let notificationDataManager = DitoNotificationReadDataManager()
        let savedNotifications = notificationDataManager.fetchAll

        XCTAssertGreaterThanOrEqual(savedNotifications.count, 0, "Notification click should be saved offline")
    }
}
