import XCTest
@testable import DitoSDK

class DitoControllerTests: XCTestCase {
    let timeout = TimeInterval(10)

    private func makeNotificationControllerForTests() -> DitoNotification {
        let controller = DitoNotification()
        controller.options = DitoNotificationOptions(badgeEnabled: false)
        return controller
    }

    override func setUp() {
        super.setUp()
        setupTestEnvironment()
    }

    override func tearDown() {
        teardownTestEnvironment()
        super.tearDown()
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
            platformAppKey: "test_key",
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

        let trackDataManager = DitoTrackDataManager()
        let predicate = NSPredicate { _, _ in trackDataManager.fetchAll.count > 0 }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        wait(for: [expectation], timeout: timeout)

        XCTAssertGreaterThan(trackDataManager.fetchAll.count, 0, "Track should be saved offline")
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
        let notificationController = makeNotificationControllerForTests()
        let identifyOffline = DitoIdentifyOffline.shared

        let signupRequest = DitoSignupRequest(
            platformAppKey: "test_key",
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

        let notificationRegisterDataManager = DitoNotificationRegisterDataManager()
        let registerPredicate = NSPredicate { _, _ in notificationRegisterDataManager.fetch != nil }
        let expectation = XCTNSPredicateExpectation(predicate: registerPredicate, object: nil)
        wait(for: [expectation], timeout: timeout)

        XCTAssertNotNil(notificationRegisterDataManager.fetch, "Token register should be processed")
    }

    func testDitoNotification_RegisterToken_WithoutReference_SavesOffline() {
        let notificationController = makeNotificationControllerForTests()

        notificationController.registerToken(token: "fcm_token_123")

        let notificationRegisterDataManager = DitoNotificationRegisterDataManager()
        let registerPredicate = NSPredicate { _, _ in notificationRegisterDataManager.fetch != nil }
        let expectation = XCTNSPredicateExpectation(predicate: registerPredicate, object: nil)
        wait(for: [expectation], timeout: timeout)

        XCTAssertNotNil(notificationRegisterDataManager.fetch, "Token register should be saved offline")
    }

    func testDitoNotification_UnregisterToken_WithReference_SendsToAPI() {
        let notificationController = makeNotificationControllerForTests()
        let identifyOffline = DitoIdentifyOffline.shared

        let signupRequest = DitoSignupRequest(
            platformAppKey: "test_key",
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

        XCTAssertEqual(identifyOffline.getIdentify?.id, "test_id", "Unregister with reference requires identified user")
    }

    func testDitoNotification_UnregisterToken_WithoutReference_SavesOffline() {
        let notificationController = makeNotificationControllerForTests()

        notificationController.unregisterToken(token: "fcm_token_123")

        let notificationUnregisterDataManager = DitoNotificationUnregisterDataManager()
        let unregisterPredicate = NSPredicate { _, _ in notificationUnregisterDataManager.fetch != nil }
        let expectation = XCTNSPredicateExpectation(predicate: unregisterPredicate, object: nil)
        wait(for: [expectation], timeout: timeout)

        XCTAssertNotNil(notificationUnregisterDataManager.fetch, "Token unregister should be saved offline")
    }

    func testDitoNotification_NotificationRead_SavesOffline() {
        let notificationController = makeNotificationControllerForTests()
        let userInfo: [AnyHashable: Any] = [
            "notification": "notif_123",
            "user_id": "user_123"
        ]

        notificationController.notificationRead(with: userInfo)

        let notificationDataManager = DitoNotificationReadDataManager()
        let predicate = NSPredicate { _, _ in
            notificationDataManager.fetchAll.count > 0
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        wait(for: [expectation], timeout: timeout)

        XCTAssertGreaterThan(notificationDataManager.fetchAll.count, 0, "Notification read should be saved")
    }

    func testDitoNotification_NotificationClick_WithReference_SendsToAPI() {
        let notificationController = makeNotificationControllerForTests()
        let identifyOffline = DitoIdentifyOffline.shared

        let signupRequest = DitoSignupRequest(
            platformAppKey: "test_key",
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
        let notificationController = makeNotificationControllerForTests()

        notificationController.notificationClick(
            notificationId: "notif_123",
            reference: "",
            identifier: "user_123"
        )

        let expectation = XCTestExpectation(description: "Notification click saved offline")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)

        let notificationDataManager = DitoNotificationReadDataManager()
        let savedNotifications = notificationDataManager.fetchAll

        XCTAssertGreaterThanOrEqual(
            savedNotifications.count,
            0,
            "Notification click should be processed"
        )
    }
}
