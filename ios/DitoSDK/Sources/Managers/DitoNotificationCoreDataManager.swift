import CoreData
import Foundation
import os.log

class DitoNotificationCoreDataManager {

    nonisolated(unsafe) static let shared = DitoNotificationCoreDataManager()

    private var container: NSPersistentContainer?

    func setup(container: NSPersistentContainer) {
        self.container = container
        self.container?.viewContext.automaticallyMergesChangesFromParent = true
    }

    func insert(notificationId: String, reference: String, title: String, message: String, link: String) {
        guard let container = container else { return }
        let context = container.newBackgroundContext()
        context.undoManager = nil
        context.performAndWait {
            let record = DitoNotificationRecord(context: context)
            record.id = UUID().uuidString
            record.notificationId = notificationId
            record.reference = reference
            record.title = title
            record.message = message
            record.link = link
            record.receivedAt = Date()
            record.isRead = false
            do {
                try context.save()
            } catch {
                os_log("DitoNotificationCoreDataManager insert error: %@", type: .error, error.localizedDescription)
            }
        }
    }

    func getAll() -> [DitoNotificationRecord] {
        guard let container = container else { return [] }
        let context = container.viewContext
        var results: [DitoNotificationRecord] = []
        context.performAndWait {
            let request = DitoNotificationRecord.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "receivedAt", ascending: false)]
            request.returnsObjectsAsFaults = false
            do {
                results = try context.fetch(request)
            } catch {
                os_log("DitoNotificationCoreDataManager getAll error: %@", type: .error, error.localizedDescription)
            }
        }
        return results
    }

    func markAsRead(id: String) {
        guard let container = container else { return }
        let context = container.viewContext
        context.performAndWait {
            let request = DitoNotificationRecord.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)
            do {
                let results = try context.fetch(request)
                results.first?.isRead = true
                try context.save()
            } catch {
                os_log("DitoNotificationCoreDataManager markAsRead error: %@", type: .error, error.localizedDescription)
            }
        }
    }

    func markAsReadByNotificationId(_ notificationId: String) {
        guard let container = container else { return }
        let context = container.viewContext
        context.performAndWait {
            let request = DitoNotificationRecord.fetchRequest()
            request.predicate = NSPredicate(format: "notificationId == %@", notificationId)
            request.fetchLimit = 1
            do {
                let results = try context.fetch(request)
                results.first?.isRead = true
                if !results.isEmpty {
                    try context.save()
                }
            } catch {
                os_log("DitoNotificationCoreDataManager markAsReadByNotificationId error: %@", type: .error, error.localizedDescription)
            }
        }
    }
}
