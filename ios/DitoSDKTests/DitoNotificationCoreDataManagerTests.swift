import CoreData
import XCTest
@testable import DitoSDK

final class DitoNotificationCoreDataManagerTests: XCTestCase {

    var sut: DitoNotificationCoreDataManager!
    var container: NSPersistentContainer!

    override func setUpWithError() throws {
        guard
            let modelURL = Bundle(for: DitoNotificationCoreDataManager.self).url(
                forResource: "DitoDataModel",
                withExtension: "momd"
            ),
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            throw XCTestError(.failureWhileWaiting, userInfo: [NSLocalizedDescriptionKey: "DitoDataModel.momd not found"])
        }
        container = NSPersistentContainer(name: "DitoDataModel", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let error = loadError {
            throw error
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        sut = DitoNotificationCoreDataManager()
        sut.setup(container: container)
    }

    override func tearDownWithError() throws {
        sut = nil
        container = nil
    }

    // MARK: - insert + getAll

    func testInsertAndGetAll() throws {
        // Arrange
        // Act
        sut.insert(notificationId: "n1", reference: "ref1", title: "Test", message: "Body", link: "https://example.com")
        let all = sut.getAll()

        // Assert
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].notificationId, "n1")
        XCTAssertFalse(all[0].isRead)
    }

    // MARK: - markAsRead

    func testMarkAsRead() throws {
        // Arrange
        sut.insert(notificationId: "n2", reference: "ref2", title: "T", message: "M", link: "L")
        let all = sut.getAll()
        XCTAssertEqual(all.count, 1)
        let recordId = all[0].id

        // Act
        sut.markAsRead(id: recordId ?? "")
        let updated = sut.getAll()

        // Assert
        XCTAssertEqual(updated.count, 1)
        XCTAssertTrue(updated[0].isRead)
    }
}
