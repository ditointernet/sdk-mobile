import CoreData
import Foundation

struct OfflinePersistedTrack: Sendable {
  let objectID: NSManagedObjectID
  let event: String?
  let retry: Int16
}

struct DitoTrackDataManager {

  @discardableResult
  func save(event: String?, retry: Int16 = 1) -> Bool {
    var success = false
    let semaphore = DispatchSemaphore(value: 0)

    DitoCoreDataManager.shared.performBackgroundTask { context in
      guard
        let track = NSEntityDescription.insertNewObject(
          forEntityName: "Track",
          into: context
        ) as? Track
      else {
        DitoLogger.error("Failed to create Track entity")
        semaphore.signal()
        return
      }

      track.event = event
      track.retry = retry

      do {
        try context.save()
        DitoLogger.information("Track Saved Successfully!!!")
        success = true
      } catch {
        DitoLogger.error(
          "Failed to save Track: \(error.localizedDescription)"
        )
        success = false
      }
      semaphore.signal()
    }

    semaphore.wait()
    return success
  }

  @discardableResult
  func update(id: NSManagedObjectID, event: String?, retry: Int16) -> Bool {
    guard let context = DitoCoreDataManager.shared.newBackgroundContext()
    else {
      DitoLogger.error("Failed to create background context for update")
      return false
    }

    var success = false
    context.performAndWait {
      do {
        guard let track = try context.existingObject(with: id) as? Track
        else {
          DitoLogger.error("Track with ID not found")
          return
        }

        track.event = event
        track.retry = retry

        try context.save()
        DitoLogger.information("Track Updated Successfully!!!")
        success = true
      } catch {
        DitoLogger.error(
          "Failed to update Track: \(error.localizedDescription)"
        )
        success = false
      }
    }

    return success
  }

  func fetchOfflinePersistedTracks() -> [OfflinePersistedTrack] {
    guard let context = DitoCoreDataManager.shared.newBackgroundContext()
    else {
      DitoLogger.error("Failed to create background context for fetch")
      return []
    }

    var results: [OfflinePersistedTrack] = []
    context.performAndWait {
      let fetchRequest = NSFetchRequest<Track>(entityName: "Track")
      fetchRequest.returnsObjectsAsFaults = false

      do {
        let fetched = try context.fetch(fetchRequest)
        results = fetched.map {
          OfflinePersistedTrack(objectID: $0.objectID, event: $0.event, retry: $0.retry)
        }
        DitoLogger.information(
          "\(results.count) Tracks found - Successfully!!!"
        )
      } catch {
        DitoLogger.error(
          "Error fetching Tracks: \(error.localizedDescription)"
        )
      }
    }

    return results
  }

  @discardableResult
  func delete(with id: NSManagedObjectID) -> Bool {
    guard let context = DitoCoreDataManager.shared.newBackgroundContext()
    else {
      DitoLogger.error("Failed to create background context for delete")
      return false
    }

    var success = false
    context.performAndWait {
      do {
        guard let track = try context.existingObject(with: id) as? Track
        else {
          DitoLogger.error("Track with ID not found")
          return
        }

        context.delete(track)
        try context.save()
        DitoLogger.information("Track Deleted - Successfully!!!")
        success = true
      } catch {
        DitoLogger.error(
          "Error deleting Track: \(error.localizedDescription)"
        )
        success = false
      }
    }

    return success
  }
}
