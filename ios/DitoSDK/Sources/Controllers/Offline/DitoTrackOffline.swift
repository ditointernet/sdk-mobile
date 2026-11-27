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

    /// `userId`: the row's owner, nil when anonymous or not known yet (sent with the user current at retry).
    func track(event: DitoEventRequest, anonymous: Bool = false, userId: String? = nil) {

        if self.identifyOffline.getSavingState {
            self.identifyOffline.setIdentityCompletionClosure{
                self.completeTrack(event: event, anonymous: anonymous, userId: userId)
            }
        } else {
            self.completeTrack(event: event, anonymous: anonymous, userId: userId)
        }
    }

    func completeTrack(event: DitoEventRequest, anonymous: Bool = false, userId: String? = nil) {
        Self.persistenceQueue.async {
            guard let json = event.toString, !json.isEmpty else {
                DitoLogger.error("Track offline: falha ao serializar DitoEventRequest")
                return
            }
            self.trackDataManager.save(event: json, anonymous: anonymous, userId: anonymous ? nil : userId)
        }
    }

    var reference: String? {
        return identifyOffline.getIdentify?.reference
    }

    /// The user of the saved identify, confirmed or not.
    var identifyId: String? {
        guard let id = identifyOffline.getIdentify?.id, !id.isEmpty else { return nil }
        return id
    }

    var identityState: DitoIdentityState {
        identifyOffline.identityState
    }

    var offlinePersistedTracks: [OfflinePersistedTrack] {
        trackDataManager.fetchOfflinePersistedTracks()
    }

    func persistedTracks(anonymous: Bool) -> [OfflinePersistedTrack] {
        trackDataManager.fetchOfflinePersistedTracks(anonymous: anonymous)
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
