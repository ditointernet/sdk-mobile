import Foundation
import CoreData

struct DitoTrackOffline {

    private var trackDataManager: DitoTrackDataManager
    private let identifyOffline: DitoIdentifyOffline

    init(trackDataManager: DitoTrackDataManager = .init(), identifyOffline: DitoIdentifyOffline = .shared) {
        self.trackDataManager = trackDataManager
        self.identifyOffline = identifyOffline
    }

    func checkIdentifyState() -> Bool {
        if self.identifyOffline.getSavingState {return true}
        return false
    }

    func setTrackCompletion(closure: @escaping () -> ()) {
        self.identifyOffline.setIdentityCompletionClosure{closure()}
    }

    func track(event: DitoEventRequest) {

        if self.identifyOffline.getSavingState {
            self.identifyOffline.setIdentityCompletionClosure{
                self.completeTrack(event: event)
            }
        } else {
            self.completeTrack(event: event)
        }
    }

    func completeTrack(event: DitoEventRequest) {

        DispatchQueue.global().async {
            let json = event.toString
            self.trackDataManager.save(event: json)
        }

    }

    var reference: String? {
        return identifyOffline.getIdentify?.id
    }

    var getTrack: [Track] {
        return trackDataManager.fetchAll
    }

    func update(id: NSManagedObjectID, event: DitoEventRequest, retry: Int16) {
        let json = event.toString
        trackDataManager.update(id: id, event: json, retry: retry)
    }

    func delete(id: NSManagedObjectID) {
        trackDataManager.delete(with: id)
    }
}
