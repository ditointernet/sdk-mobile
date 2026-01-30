import XCTest
@testable import DitoSDK

class DitoOfflineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        setupTestEnvironment()
    }

    override func tearDown() {
        teardownTestEnvironment()
        super.tearDown()
    }

    func testDitoIdentifyOffline_InitiateIdentify_SavesStamp() {
        let identifyOffline = DitoIdentifyOffline.shared

        let result = identifyOffline.initiateIdentify()

        let savingState = identifyOffline.getSavingState
        XCTAssertTrue(savingState, "Saving state should be true after initiate")
    }

    func testDitoIdentifyOffline_FinishIdentify_ExecutesCompletions() {
        let identifyOffline = DitoIdentifyOffline.shared
        let expectation = XCTestExpectation(description: "Completion executed")

        identifyOffline.initiateIdentify()
        identifyOffline.setIdentityCompletionClosure {
            expectation.fulfill()
        }

        identifyOffline.finishIdentify()

        wait(for: [expectation], timeout: 2.0)
    }

    func testDitoIdentifyOffline_GetSavingState_ReturnsTrueWhenRecent() {
        let identifyOffline = DitoIdentifyOffline.shared

        identifyOffline.initiateIdentify()

        let savingState = identifyOffline.getSavingState
        XCTAssertTrue(savingState, "Saving state should be true when recent")
    }

    func testDitoIdentifyOffline_GetSavingState_ReturnsFalseWhenOld() {
        let identifyOffline = DitoIdentifyOffline.shared

        identifyOffline.initiateIdentify()

        let oldDate = Date(timeIntervalSince1970: Date().timeIntervalSince1970 - 120)
        UserDefaults.savingState = oldDate.timeIntervalSince1970

        let savingState = identifyOffline.getSavingState
        XCTAssertFalse(savingState, "Saving state should be false when old")
    }

    func testDitoIdentifyOffline_Identify_SavesWithCorrectParams() {
        let identifyOffline = DitoIdentifyOffline.shared
        let testId = "test_id_123"
        let testReference = "ref_123"
        let signupRequest = DitoSignupRequest(
            platformApiKey: "test_key",
            sha1Signature: "test_signature",
            userData: nil
        )

        identifyOffline.identify(
            id: testId,
            params: signupRequest,
            reference: testReference,
            send: true
        )

        let fetched = identifyOffline.getIdentify
        XCTAssertNotNil(fetched, "Identify should be saved")
        XCTAssertEqual(fetched?.id, testId, "ID should match")
        XCTAssertEqual(fetched?.reference, testReference, "Reference should match")
    }

    func testDitoTrackOffline_CheckIdentifyState_ReturnsTrueWhenSaving() {
        let trackOffline = DitoTrackOffline()

        DitoIdentifyOffline.shared.initiateIdentify()

        let isSaving = trackOffline.checkIdentifyState()
        XCTAssertTrue(isSaving, "Should return true when identify is saving")
    }

    func testDitoTrackOffline_CheckIdentifyState_ReturnsFalseWhenNotSaving() {
        let trackOffline = DitoTrackOffline()

        DitoIdentifyOffline.shared.finishIdentify()

        let isSaving = trackOffline.checkIdentifyState()
        XCTAssertFalse(isSaving, "Should return false when identify is not saving")
    }

    func testDitoTrackOffline_Track_SavesWhenNoIdentify() {
        let trackOffline = DitoTrackOffline()
        let eventRequest = DitoEventRequest(
            platformApiKey: "test_key",
            sha1Signature: "test_signature",
            event: DitoEvent(action: "test_action")
        )

        trackOffline.track(event: eventRequest)

        let expectation = XCTestExpectation(description: "Track saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        let tracks = trackOffline.getTrack
        XCTAssertGreaterThan(tracks.count, 0, "Track should be saved")
    }

    func testDitoTrackOffline_Reference_ReturnsCorrectValue() {
        let trackOffline = DitoTrackOffline()
        let identifyOffline = DitoIdentifyOffline.shared
        let testReference = "ref_123"

        let signupRequest = DitoSignupRequest(
            platformApiKey: "test_key",
            sha1Signature: "test_signature",
            userData: nil
        )

        identifyOffline.identify(
            id: "test_id",
            params: signupRequest,
            reference: testReference,
            send: true
        )

        let reference = trackOffline.reference
        XCTAssertEqual(reference, testReference, "Reference should match")
    }

    func testDitoNotificationOffline_NotificationRegister_SavesOffline() {
        let notificationOffline = DitoNotificationOffline()
        let tokenRequest = DitoTokenRequest(
            platformApiKey: "test_key",
            sha1Signature: "test_signature",
            token: "fcm_token_123"
        )

        notificationOffline.notificationRegister(tokenRequest)

        let expectation = XCTestExpectation(description: "Notification register saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        let fetched = notificationOffline.getNotificationRegister
        XCTAssertNotNil(fetched, "Notification register should be saved")
    }

    func testDitoNotificationOffline_NotificationUnregister_SavesOffline() {
        let notificationOffline = DitoNotificationOffline()
        let tokenRequest = DitoTokenRequest(
            platformApiKey: "test_key",
            sha1Signature: "test_signature",
            token: "fcm_token_123"
        )

        notificationOffline.notificationUnregister(tokenRequest)

        let expectation = XCTestExpectation(description: "Notification unregister saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        let fetched = notificationOffline.getNotificationUnregister
        XCTAssertNotNil(fetched, "Notification unregister should be saved")
    }

    func testDitoNotificationOffline_NotificationRead_SavesOffline() {
        let notificationOffline = DitoNotificationOffline()
        let notificationRequest = DitoNotificationOpenRequest(
            platformApiKey: "test_key",
            sha1Signature: "test_signature",
            data: DitoDataNotification(identifier: "id_123", reference: "ref_123")
        )

        notificationOffline.notificationRead(notificationRequest)

        let expectation = XCTestExpectation(description: "Notification read saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        let notifications = notificationOffline.getNotificationRead
        XCTAssertGreaterThan(notifications.count, 0, "Notification read should be saved")
    }

    func testDitoNotificationOffline_Reference_ReturnsCorrectValue() {
        let notificationOffline = DitoNotificationOffline()
        let identifyOffline = DitoIdentifyOffline.shared
        let testReference = "ref_123"

        let signupRequest = DitoSignupRequest(
            platformApiKey: "test_key",
            sha1Signature: "test_signature",
            userData: nil
        )

        identifyOffline.identify(
            id: "test_id",
            params: signupRequest,
            reference: testReference,
            send: true
        )

        let reference = notificationOffline.reference
        XCTAssertEqual(reference, testReference, "Reference should match")
    }
}
