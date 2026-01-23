import CoreData
import Foundation

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

  var fetchAll: [Track] {
    guard let context = DitoCoreDataManager.shared.newBackgroundContext()
    else {
      DitoLogger.error("Failed to create background context for fetch")
      return []
    }

    var results: [Track] = []
    context.performAndWait {
      let fetchRequest = NSFetchRequest<Track>(entityName: "Track")
      fetchRequest.returnsObjectsAsFaults = false

      do {
        results = try context.fetch(fetchRequest)
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
