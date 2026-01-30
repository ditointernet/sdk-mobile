import Foundation
import CoreData
@testable import DitoSDK

class TestHelpers {

    static func resetAllState() {
        resetCoreData()
        resetUserDefaults()
        resetSingletons()
    }

    static func resetCoreData() {
        let trackDataManager = DitoTrackDataManager()
        let tracks = trackDataManager.fetchAll
        for track in tracks {
            _ = trackDataManager.delete(with: track.objectID)
        }

        let notificationReadDataManager = DitoNotificationReadDataManager()
        let notifications = notificationReadDataManager.fetchAll
        for notification in notifications {
            _ = notificationReadDataManager.delete(with: notification.objectID)
        }

        let notificationRegisterDataManager = DitoNotificationRegisterDataManager()
        if let register = notificationRegisterDataManager.fetch {
            _ = notificationRegisterDataManager.delete()
        }

        let notificationUnregisterDataManager = DitoNotificationUnregisterDataManager()
        if let unregister = notificationUnregisterDataManager.fetch {
            _ = notificationUnregisterDataManager.delete()
        }
    }

    static func resetUserDefaults() {
        DitoIdentifyDataManager.shared.deleteIdentifyStamp()

        let identifyDataManager = DitoIdentifyDataManager()
        if let identify = identifyDataManager.fetch {
            _ = identifyDataManager.delete(id: identify.id)
        }
    }

    static func resetSingletons() {
        DitoIdentifyDataManager.shared.identitySaveCallback = nil
        DitoIdentifyOffline.shared.finishIdentify()
    }

    static func createInMemoryCoreDataStack() -> NSPersistentContainer? {
        let container = NSPersistentContainer(name: "DitoDataModel")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { description, error in
            if let error = error {
                loadError = error
            }
        }

        if loadError != nil {
            return nil
        }

        return container
    }

    static func waitForAsyncOperation(timeout: TimeInterval = 2.0, operation: @escaping (@escaping () -> Void) -> Void) -> Bool {
        let expectation = XCTestExpectation(description: "Async operation")

        operation {
            expectation.fulfill()
        }

        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    static func createMockDitoUser(
        name: String = "Test User",
        email: String = "test@example.com",
        gender: DitoGender? = .masculino,
        location: String? = "São Paulo"
    ) -> DitoUser {
        DitoUser(
            name: name,
            gender: gender,
            email: email,
            birthday: Date(),
            location: location,
            createdAt: Date(),
            customData: nil
        )
    }

    static func createMockDitoEvent(
        action: String = "test_action",
        revenue: Double? = nil,
        customData: [String: Any]? = nil
    ) -> DitoEvent {
        DitoEvent(
            action: action,
            revenue: revenue,
            createdAt: Date(),
            customData: customData
        )
    }

    static func createMockUserInfo() -> [AnyHashable: Any] {
        return [
            "notification": "notif_123",
            "user_id": "user_123",
            "link": "app://deeplink",
            "reference": "ref_123",
            "title": "Test Title",
            "message": "Test Message"
        ]
    }
}

extension XCTestCase {

    func setupTestEnvironment() {
        TestHelpers.resetAllState()
    }

    func teardownTestEnvironment() {
        TestHelpers.resetAllState()
    }

    func waitForExpectation(
        _ description: String,
        timeout: TimeInterval = 5.0,
        handler: @escaping (XCTestExpectation) -> Void
    ) {
        let expectation = XCTestExpectation(description: description)
        handler(expectation)
        wait(for: [expectation], timeout: timeout)
    }

    func assertDataSaved<T>(
        _ fetchOperation: () -> T?,
        errorMessage: String,
        file: StaticString = #file,
        line: UInt = #line
    ) where T: AnyObject {
        guard let _ = fetchOperation() else {
            XCTFail(errorMessage, file: file, line: line)
            return
        }
    }

    func assertDataNotSaved<T>(
        _ fetchOperation: () -> T?,
        errorMessage: String,
        file: StaticString = #file,
        line: UInt = #line
    ) where T: AnyObject {
        if let _ = fetchOperation() {
            XCTFail(errorMessage, file: file, line: line)
        }
    }
}
