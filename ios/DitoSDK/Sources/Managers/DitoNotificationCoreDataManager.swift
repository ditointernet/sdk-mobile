import CoreData
import Foundation
import os.log

/// Inbox storage for received notifications.
///
/// The rich-push columns (`image`, `customData`) are optional on purpose: the
/// `.xcdatamodel` is still unversioned, and an additive optional attribute is the
/// case Core Data's automatic inferred mapping handles. The next *non-additive*
/// change to this entity needs real model versioning first.
class DitoNotificationCoreDataManager {

    nonisolated(unsafe) static let shared = DitoNotificationCoreDataManager()

    private var container: NSPersistentContainer?

    func setup(container: NSPersistentContainer) {
        self.container = container
        self.container?.viewContext.automaticallyMergesChangesFromParent = true
    }

    func insert(
        notificationId: String,
        title: String,
        message: String,
        link: String,
        image: String = "",
        customData: [String: String] = [:]
    ) {
        guard let container = container else { return }
        let context = container.newBackgroundContext()
        context.undoManager = nil
        context.performAndWait {
            let record = DitoNotificationRecord(context: context)
            record.id = UUID().uuidString
            record.notificationId = notificationId
            // The model still declares `reference` as non-optional, so the column
            // has to be written. It is intentionally empty: the field was retired
            // from Dito payloads and the SDK no longer reads it. Dropping the
            // attribute is a separate, migration-bearing change.
            record.reference = ""
            record.title = title
            record.message = message
            record.link = link
            record.image = image.isEmpty ? nil : image
            record.customData = Self.encode(customData)
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

    /// Custom data is stored as a JSON string, matching how the other entities
    /// in this model persist structured payloads.
    static func encode(_ customData: [String: String]) -> String? {
        guard !customData.isEmpty else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: customData, options: [.sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> [String: String] {
        guard let json, !json.isEmpty, let data = json.data(using: .utf8) else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: String] ?? [:]
    }
}
