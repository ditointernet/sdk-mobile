import Foundation
import CoreData

class DitoIdentifyDataManager {

    nonisolated(unsafe) static let shared: DitoIdentifyDataManager = {
        let sharedInstance = DitoIdentifyDataManager()
        return sharedInstance
    }()

    var identitySaveCallback: (() -> ())? = nil
    private var completionClosures: [() -> ()] = []

    @discardableResult
    func saveIdentifyStamp() -> Bool {
        UserDefaults.savingState = NSDate().timeIntervalSince1970
        return true
    }

    var fetchSavingState: Double? {

        let stamp = UserDefaults.savingState
        if stamp == 0 { return nil }

        return stamp
    }

    @discardableResult
    func deleteIdentifyStamp() -> Bool {

        UserDefaults.savingState = -1
        return true
    }

    @discardableResult
    func save(id: String, reference: String?, json: String?, send: Bool) -> Bool {

        let newIdentify = IdentifyDefaults(id: id, json: json, reference: reference, send: send)
        UserDefaults.identify = newIdentify

        return true
    }

    @discardableResult
    func update(id: String, reference: String?, json: String?, send: Bool) -> Bool {
        save(id: id, reference: reference, json: json, send: send)
        return true
    }

    var fetch: IdentifyDefaults? {

        guard let savedIdentify = UserDefaults.identify else {return nil}
        return savedIdentify
    }

    @discardableResult
    func delete(id: String) -> Bool {

        let checkIdentify = UserDefaults.identify
        if checkIdentify?.id == id {
            UserDefaults.identify = nil
        }
        return true
    }

    func addCompletionClosure(_ closure: @escaping () -> ()) {
        completionClosures.append(closure)
    }

    func executeAllCompletions() {
        // Execute the legacy callback if set
        identitySaveCallback?()

        // Execute all registered closures
        for closure in completionClosures {
            closure()
        }

        // Clear the closures list
        completionClosures.removeAll()
    }
}
