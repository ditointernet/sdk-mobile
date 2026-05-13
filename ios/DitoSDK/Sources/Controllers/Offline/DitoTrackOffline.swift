import Foundation
import CoreData

struct DitoTrackOffline {

    private static let persistenceQueue = DispatchQueue(
        label: "br.com.dito.ditosdk.trackoffline.persistence"
    )

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
        Self.persistenceQueue.async {
            guard let json = event.toString, !json.isEmpty else {
                DitoLogger.error("Track offline: falha ao serializar DitoEventRequest")
                return
            }
            self.trackDataManager.save(event: json)
        }
    }

    var reference: String? {
        return identifyOffline.getIdentify?.reference
    }

    var offlinePersistedTracks: [OfflinePersistedTrack] {
        trackDataManager.fetchOfflinePersistedTracks()
    }

    func update(id: NSManagedObjectID, event: DitoEventRequest, retry: Int16) {
        Self.persistenceQueue.sync {
            let json = event.toString
            trackDataManager.update(id: id, event: json, retry: retry)
        }
    }

    func delete(id: NSManagedObjectID) {
        Self.persistenceQueue.sync {
            trackDataManager.delete(with: id)
        }
    }
}
