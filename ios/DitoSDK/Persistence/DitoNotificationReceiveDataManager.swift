import CoreData
import Foundation

struct DitoNotificationReceiveDataManager {

  @discardableResult
  func save(with json: String?, retry: Int16 = 1) -> Bool {
    var success = false
    let semaphore = DispatchSemaphore(value: 0)

    DitoCoreDataManager.shared.performBackgroundTask { context in
      guard
        let row = NSEntityDescription.insertNewObject(
          forEntityName: "NotificationReceive",
          into: context
        ) as? NotificationReceive
      else {
        DitoLogger.error("Failed to create NotificationReceive entity")
        semaphore.signal()
        return
      }

      row.retry = retry
      row.json = json

      do {
        try context.save()
        DitoLogger.information("NotificationReceive Saved Successfully!!!")
        success = true
      } catch {
        DitoLogger.error(
          "Failed to save NotificationReceive: \(error.localizedDescription)"
        )
        success = false
      }
      semaphore.signal()
    }

    semaphore.wait()
    return success
  }

  @discardableResult
  func update(id: NSManagedObjectID, retry: Int16) -> Bool {
    guard let context = DitoCoreDataManager.shared.newBackgroundContext()
    else {
      DitoLogger.error("Failed to create background context for NotificationReceive update")
      return false
    }

    var success = false
    context.performAndWait {
      do {
        guard let row = try context.existingObject(with: id) as? NotificationReceive
        else {
          DitoLogger.error("NotificationReceive with ID not found")
          return
        }

        row.retry = retry

        try context.save()
        DitoLogger.information("NotificationReceive Updated Successfully!!!")
        success = true
      } catch {
        DitoLogger.error(
          "Failed to update NotificationReceive: \(error.localizedDescription)"
        )
        success = false
      }
    }

    return success
  }

  var fetchAll: [NotificationReceive] {
    guard let context = DitoCoreDataManager.shared.newBackgroundContext()
    else {
      DitoLogger.error("Failed to create background context for NotificationReceive fetch")
      return []
    }

    var results: [NotificationReceive] = []
    context.performAndWait {
      let fetchRequest = NSFetchRequest<NotificationReceive>(entityName: "NotificationReceive")
      fetchRequest.returnsObjectsAsFaults = false

      do {
        results = try context.fetch(fetchRequest)
        DitoLogger.information(
          "\(results.count) NotificationReceive row(s) found - Successfully!!!"
        )
      } catch {
        DitoLogger.error(
          "Error fetching NotificationReceive: \(error.localizedDescription)"
        )
      }
    }

    return results
  }

  @discardableResult
  func delete(with id: NSManagedObjectID) -> Bool {
    guard let context = DitoCoreDataManager.shared.newBackgroundContext()
    else {
      DitoLogger.error("Failed to create background context for NotificationReceive delete")
      return false
    }

    var success = false
    context.performAndWait {
      do {
        guard let row = try context.existingObject(with: id) as? NotificationReceive
        else {
          DitoLogger.error("NotificationReceive with ID not found")
          return
        }

        context.delete(row)
        try context.save()
        DitoLogger.information("NotificationReceive Deleted - Successfully!!!")
        success = true
      } catch {
        DitoLogger.error(
          "Error deleting NotificationReceive: \(error.localizedDescription)"
        )
        success = false
      }
    }

    return success
  }
}
