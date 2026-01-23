import CoreData
import Foundation

struct DitoNotificationUnregisterDataManager {

  @discardableResult
  func save(with json: String?, retry: Int16 = 1) -> Bool {
    delete()

    var success = false
    let semaphore = DispatchSemaphore(value: 0)

    DitoCoreDataManager.shared.performBackgroundTask { context in
      guard
        let notificationUnregister = NSEntityDescription.insertNewObject(
          forEntityName: "NotificationUnregister", into: context) as? NotificationUnregister
      else {
        DitoLogger.error("Failed to create NotificationUnregister entity")
        semaphore.signal()
        return
      }

      notificationUnregister.retry = retry
      notificationUnregister.json = json

      do {
        try context.save()
        DitoLogger.information("NotificationUnregister Saved Successfully!!!")
        success = true
      } catch {
        DitoLogger.error("Failed to save NotificationUnregister: \(error.localizedDescription)")
        success = false
      }
      semaphore.signal()
    }

    semaphore.wait()
    return success
  }

  @discardableResult
  func update(id: NSManagedObjectID, retry: Int16) -> Bool {
    guard let context = DitoCoreDataManager.shared.newBackgroundContext() else {
      DitoLogger.error("Failed to create background context for update")
      return false
    }

    var success = false
    context.performAndWait {
      do {
        guard
          let notificationUnregister = try context.existingObject(with: id)
            as? NotificationUnregister
        else {
          DitoLogger.error("NotificationUnregister with ID not found")
          return
        }

        notificationUnregister.retry = retry
        try context.save()
        DitoLogger.information("NotificationUnregister Updated Successfully!!!")
        success = true
      } catch {
        DitoLogger.error("Failed to update NotificationUnregister: \(error.localizedDescription)")
        success = false
      }
    }

    return success
  }

  var fetch: NotificationUnregister? {
    guard let context = DitoCoreDataManager.shared.newBackgroundContext() else {
      DitoLogger.error("Failed to create background context for fetch")
      return nil
    }

    var result: NotificationUnregister?
    context.performAndWait {
      let fetchRequest = NSFetchRequest<NotificationUnregister>(
        entityName: "NotificationUnregister")
      fetchRequest.fetchLimit = 1
      fetchRequest.returnsObjectsAsFaults = false

      do {
        result = try context.fetch(fetchRequest).first
        if result != nil {
          DitoLogger.information("NotificationUnregister found - Successfully!!!")
        }
      } catch {
        DitoLogger.error("Error fetching NotificationUnregister: \(error.localizedDescription)")
      }
    }

    return result
  }

  @discardableResult
  func delete() -> Bool {
    guard let context = DitoCoreDataManager.shared.newBackgroundContext() else {
      DitoLogger.error("Failed to create background context for delete")
      return false
    }

    var success = false
    context.performAndWait {
      do {
        let fetchRequest = NSFetchRequest<NotificationUnregister>(
          entityName: "NotificationUnregister")
        fetchRequest.returnsObjectsAsFaults = false

        let notificationUnregisters = try context.fetch(fetchRequest)
        for managedObject in notificationUnregisters {
          context.delete(managedObject)
        }

        try context.save()
        DitoLogger.information("NotificationUnregister Deleted - Successfully!!!")
        success = true
      } catch {
        DitoLogger.error("Error deleting NotificationUnregister: \(error.localizedDescription)")
        success = false
      }
    }

    return success
  }
}
