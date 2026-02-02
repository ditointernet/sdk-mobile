import XCTest
import CoreData
@testable import DitoSDK

class DitoDataManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        setupTestEnvironment()
    }

    override func tearDown() {
        teardownTestEnvironment()
        super.tearDown()
    }

    func testDitoIdentifyDataManager_Save_WithValidData() {
        let dataManager = DitoIdentifyDataManager()
        let result = dataManager.save(
            id: "test_id_123",
            reference: "ref_123",
            json: "{\"test\": \"data\"}",
            send: true
        )

        XCTAssertTrue(result, "Save should return true")
    }

    func testDitoIdentifyDataManager_Fetch_ReturnsSavedData() {
        let dataManager = DitoIdentifyDataManager()
        let testId = "test_id_123"
        let testReference = "ref_123"

        _ = dataManager.save(
            id: testId,
            reference: testReference,
            json: "{\"test\": \"data\"}",
            send: true
        )

        let fetched = dataManager.fetch

        XCTAssertNotNil(fetched, "Fetched data should not be nil")
        XCTAssertEqual(fetched?.id, testId, "ID should match")
        XCTAssertEqual(fetched?.reference, testReference, "Reference should match")
    }

    func testDitoIdentifyDataManager_Update_ModifiesExistingData() {
        let dataManager = DitoIdentifyDataManager()
        let testId = "test_id_123"
        let newReference = "new_ref_456"

        _ = dataManager.save(
            id: testId,
            reference: "old_ref",
            json: "{\"test\": \"data\"}",
            send: true
        )

        let updateResult = dataManager.update(
            id: testId,
            reference: newReference,
            json: "{\"test\": \"updated\"}",
            send: true
        )

        XCTAssertTrue(updateResult, "Update should return true")

        let fetched = dataManager.fetch
        XCTAssertEqual(fetched?.reference, newReference, "Reference should be updated")
    }

    func testDitoIdentifyDataManager_Delete_RemovesData() {
        let dataManager = DitoIdentifyDataManager()
        let testId = "test_id_123"

        _ = dataManager.save(
            id: testId,
            reference: "ref_123",
            json: "{\"test\": \"data\"}",
            send: true
        )

        let deleteResult = dataManager.delete(id: testId)

        XCTAssertTrue(deleteResult, "Delete should return true")

        let fetched = dataManager.fetch
        XCTAssertNil(fetched, "Fetched data should be nil after delete")
    }

    func testDitoIdentifyDataManager_SaveIdentifyStamp_CreatesStamp() {
        let dataManager = DitoIdentifyDataManager()
        let result = dataManager.saveIdentifyStamp()

        XCTAssertTrue(result, "Save stamp should return true")

        let stamp = dataManager.fetchSavingState
        XCTAssertNotNil(stamp, "Saving state should not be nil")
    }

    func testDitoIdentifyDataManager_DeleteIdentifyStamp_RemovesStamp() {
        let dataManager = DitoIdentifyDataManager()

        _ = dataManager.saveIdentifyStamp()
        let deleteResult = dataManager.deleteIdentifyStamp()

        XCTAssertTrue(deleteResult, "Delete stamp should return true")

        let stamp = dataManager.fetchSavingState
        XCTAssertNil(stamp, "Saving state should be nil after delete")
    }

    func testDitoTrackDataManager_Save_WithValidEvent() {
        let dataManager = DitoTrackDataManager()
        let eventJSON = "{\"action\": \"test_action\"}"

        let result = dataManager.save(event: eventJSON, retry: 1)

        XCTAssertTrue(result, "Save should return true")
    }

    func testDitoTrackDataManager_FetchAll_ReturnsAllTracks() {
        let dataManager = DitoTrackDataManager()

        _ = dataManager.save(event: "{\"action\": \"test1\"}", retry: 1)
        _ = dataManager.save(event: "{\"action\": \"test2\"}", retry: 1)

        let tracks = dataManager.fetchAll

        XCTAssertGreaterThanOrEqual(tracks.count, 2, "Should return at least 2 tracks")
    }

    func testDitoTrackDataManager_Update_ModifiesExistingTrack() {
        let dataManager = DitoTrackDataManager()

        _ = dataManager.save(event: "{\"action\": \"test\"}", retry: 1)

        let tracks = dataManager.fetchAll
        guard let firstTrack = tracks.first else {
            XCTFail("Should have at least one track")
            return
        }

        let updateResult = dataManager.update(
            id: firstTrack.objectID,
            event: "{\"action\": \"updated\"}",
            retry: 2
        )

        XCTAssertTrue(updateResult, "Update should return true")
    }

    func testDitoTrackDataManager_Delete_RemovesTrack() {
        let dataManager = DitoTrackDataManager()

        _ = dataManager.save(event: "{\"action\": \"test\"}", retry: 1)

        let tracks = dataManager.fetchAll
        guard let firstTrack = tracks.first else {
            XCTFail("Should have at least one track")
            return
        }

        let deleteResult = dataManager.delete(with: firstTrack.objectID)

        XCTAssertTrue(deleteResult, "Delete should return true")
    }

    func testDitoNotificationReadDataManager_Save_WithValidJSON() {
        let dataManager = DitoNotificationReadDataManager()
        let json = "{\"notification\": \"notif_123\"}"

        let result = dataManager.save(with: json, retry: 1)

        XCTAssertTrue(result, "Save should return true")
    }

    func testDitoNotificationReadDataManager_FetchAll_ReturnsAllNotifications() {
        let dataManager = DitoNotificationReadDataManager()

        _ = dataManager.save(with: "{\"notification\": \"notif_1\"}", retry: 1)
        _ = dataManager.save(with: "{\"notification\": \"notif_2\"}", retry: 1)

        let notifications = dataManager.fetchAll

        XCTAssertGreaterThanOrEqual(notifications.count, 2, "Should return at least 2 notifications")
    }

    func testDitoNotificationReadDataManager_Update_ModifiesExistingNotification() {
        let dataManager = DitoNotificationReadDataManager()

        _ = dataManager.save(with: "{\"notification\": \"notif_1\"}", retry: 1)

        let notifications = dataManager.fetchAll
        guard let firstNotification = notifications.first else {
            XCTFail("Should have at least one notification")
            return
        }

        let updateResult = dataManager.update(id: firstNotification.objectID, retry: 2)

        XCTAssertTrue(updateResult, "Update should return true")
    }

    func testDitoNotificationReadDataManager_Delete_RemovesNotification() {
        let dataManager = DitoNotificationReadDataManager()

        _ = dataManager.save(with: "{\"notification\": \"notif_1\"}", retry: 1)

        let notifications = dataManager.fetchAll
        guard let firstNotification = notifications.first else {
            XCTFail("Should have at least one notification")
            return
        }

        let deleteResult = dataManager.delete(with: firstNotification.objectID)

        XCTAssertTrue(deleteResult, "Delete should return true")
    }

    func testDitoNotificationRegisterDataManager_Save_WithValidJSON() {
        let dataManager = DitoNotificationRegisterDataManager()
        let json = "{\"token\": \"fcm_token_123\"}"

        let result = dataManager.save(with: json, retry: 1)

        XCTAssertTrue(result, "Save should return true")
    }

    func testDitoNotificationRegisterDataManager_Fetch_ReturnsSavedData() {
        let dataManager = DitoNotificationRegisterDataManager()
        let json = "{\"token\": \"fcm_token_123\"}"

        _ = dataManager.save(with: json, retry: 1)

        let fetched = dataManager.fetch

        XCTAssertNotNil(fetched, "Fetched data should not be nil")
        XCTAssertEqual(fetched?.retry, 1, "Retry should match")
    }

    func testDitoNotificationRegisterDataManager_Update_ModifiesExistingData() {
        let dataManager = DitoNotificationRegisterDataManager()

        _ = dataManager.save(with: "{\"token\": \"token1\"}", retry: 1)

        let updateResult = dataManager.update(id: nil, retry: 2)

        XCTAssertTrue(updateResult, "Update should return true")

        let fetched = dataManager.fetch
        XCTAssertEqual(fetched?.retry, 2, "Retry should be updated")
    }

    func testDitoNotificationRegisterDataManager_Delete_RemovesData() {
        let dataManager = DitoNotificationRegisterDataManager()

        _ = dataManager.save(with: "{\"token\": \"token1\"}", retry: 1)

        let deleteResult = dataManager.delete()

        XCTAssertTrue(deleteResult, "Delete should return true")

        let fetched = dataManager.fetch
        XCTAssertNil(fetched, "Fetched data should be nil after delete")
    }

    func testDitoNotificationUnregisterDataManager_Save_WithValidJSON() {
        let dataManager = DitoNotificationUnregisterDataManager()
        let json = "{\"token\": \"fcm_token_123\"}"

        let result = dataManager.save(with: json, retry: 1)

        XCTAssertTrue(result, "Save should return true")
    }

    func testDitoNotificationUnregisterDataManager_Fetch_ReturnsSavedData() {
        let dataManager = DitoNotificationUnregisterDataManager()
        let json = "{\"token\": \"fcm_token_123\"}"

        _ = dataManager.save(with: json, retry: 1)

        let fetched = dataManager.fetch

        XCTAssertNotNil(fetched, "Fetched data should not be nil")
    }

    func testDitoNotificationUnregisterDataManager_Update_ModifiesExistingData() {
        let dataManager = DitoNotificationUnregisterDataManager()

        _ = dataManager.save(with: "{\"token\": \"token1\"}", retry: 1)

        let notifications = dataManager.fetch
        guard let notification = notifications else {
            XCTFail("Should have notification")
            return
        }

        let updateResult = dataManager.update(id: notification.objectID, retry: 2)

        XCTAssertTrue(updateResult, "Update should return true")
    }

    func testDitoNotificationUnregisterDataManager_Delete_RemovesData() {
        let dataManager = DitoNotificationUnregisterDataManager()

        _ = dataManager.save(with: "{\"token\": \"token1\"}", retry: 1)

        let deleteResult = dataManager.delete()

        XCTAssertTrue(deleteResult, "Delete should return true")
    }
}
