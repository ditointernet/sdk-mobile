import Foundation
@testable import DitoSDK

class MockDitoIdentifyDataManager {
    var saveCalled = false
    var saveId: String?
    var saveReference: String?
    var saveJson: String?
    var saveSend: Bool?
    var saveResult: Bool = true

    var fetchCalled = false
    var fetchResult: IdentifyDefaults?

    var updateCalled = false
    var updateId: String?
    var updateReference: String?
    var updateJson: String?
    var updateSend: Bool?
    var updateResult: Bool = true

    var deleteCalled = false
    var deleteId: String?
    var deleteResult: Bool = true

    var saveIdentifyStampCalled = false
    var saveIdentifyStampResult: Bool = true

    var deleteIdentifyStampCalled = false
    var deleteIdentifyStampResult: Bool = true

    var fetchSavingStateResult: Double?

    var identitySaveCallback: (() -> Void)?
    var completionClosures: [() -> Void] = []

    @discardableResult
    func save(id: String, reference: String?, json: String?, send: Bool) -> Bool {
        saveCalled = true
        saveId = id
        saveReference = reference
        saveJson = json
        saveSend = send
        return saveResult
    }

    var fetch: IdentifyDefaults? {
        fetchCalled = true
        return fetchResult
    }

    @discardableResult
    func update(id: String, reference: String?, json: String?, send: Bool) -> Bool {
        updateCalled = true
        updateId = id
        updateReference = reference
        updateJson = json
        updateSend = send
        return updateResult
    }

    @discardableResult
    func delete(id: String) -> Bool {
        deleteCalled = true
        deleteId = id
        return deleteResult
    }

    @discardableResult
    func saveIdentifyStamp() -> Bool {
        saveIdentifyStampCalled = true
        return saveIdentifyStampResult
    }

    @discardableResult
    func deleteIdentifyStamp() -> Bool {
        deleteIdentifyStampCalled = true
        return deleteIdentifyStampResult
    }

    var fetchSavingState: Double? {
        return fetchSavingStateResult
    }

    func addCompletionClosure(_ closure: @escaping () -> Void) {
        completionClosures.append(closure)
    }

    func executeAllCompletions() {
        completionClosures.forEach { $0() }
        completionClosures.removeAll()
    }
}
