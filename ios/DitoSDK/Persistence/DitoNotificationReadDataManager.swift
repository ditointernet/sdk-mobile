import CoreData
import Foundation

struct DitoNotificationReadDataManager {

  @discardableResult
  func save(with json: String?, retry: Int16 = 1) -> Bool {
    var success = false
    let semaphore = DispatchSemaphore(value: 0)

    DitoCoreDataManager.shared.performBackgroundTask { context in
      guard
        let notificationRead = NSEntityDescription.insertNewObject(
          forEntityName: "NotificationRead",
          into: context
        ) as? NotificationRead
      else {
        DitoLogger.error("Failed to create NotificationRead entity")
        semaphore.signal()
        return
      }

      notificationRead.retry = retry
      notificationRead.json = json

      do {
        try context.save()
        DitoLogger.information("Notification Saved Successfully!!!")
        success = true
      } catch {
        DitoLogger.error(
          "Failed to save Notification: \(error.localizedDescription)"
        )
        success = false
      }
      semaphore.signal()
    }

    semaphore.wait()
    return success
  }

  /// Updates notification read using background context (iOS 16+ safe)
  @discardableResult
  func update(id: NSManagedObjectID, retry: Int16) -> Bool {
    guard let context = DitoCoreDataManager.shared.newBackgroundContext()
    else {
      DitoLogger.error("Failed to create background context for update")
      return false
    }

    var success = false
    context.performAndWait {
      do {
        guard
          let notificationRead = try context.existingObject(with: id)
            as? NotificationRead
        else {
          DitoLogger.error("NotificationRead with ID not found")
          return
        }

        notificationRead.retry = retry
        try context.save()
        DitoLogger.information(
          "NotificationRead Updated Successfully!!!"
        )
        success = true
      } catch {
        DitoLogger.error(
          "Failed to update NotificationRead: \(error.localizedDescription)"
        )
        success = false
      }
    }

    return success
  }

  /// Fetches all notification reads using background context
  var fetchAll: [NotificationRead] {
    guard let context = DitoCoreDataManager.shared.newBackgroundContext()
    else {
      DitoLogger.error("Failed to create background context for fetch")
      return []
    }

    var results: [NotificationRead] = []
    context.performAndWait {
      let fetchRequest = NSFetchRequest<NotificationRead>(
        entityName: "NotificationRead"
      )
      fetchRequest.returnsObjectsAsFaults = false

      do {
        results = try context.fetch(fetchRequest)
        DitoLogger.information(
          "\(results.count) Notifications found - Successfully!!!"
        )
      } catch {
        DitoLogger.error(
          "Error fetching Notifications: \(error.localizedDescription)"
        )
      }
    }

    return results
  }

  /// Deletes notification read using background context (iOS 16+ safe)
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
        guard
          let notificationRead = try context.existingObject(with: id)
            as? NotificationRead
        else {
          DitoLogger.error("NotificationRead with ID not found")
          return
        }

        context.delete(notificationRead)
        try context.save()
        DitoLogger.information("Notification Deleted - Successfully!!!")
        success = true
      } catch {
        DitoLogger.error(
          "Error deleting NotificationRead: \(error.localizedDescription)"
        )
        success = false
      }
    }

    return success
  }
}
