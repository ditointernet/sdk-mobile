import CoreData
import Foundation

extension DitoNotificationRecord {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DitoNotificationRecord> {
        return NSFetchRequest<DitoNotificationRecord>(entityName: "DitoNotificationRecord")
    }

    @NSManaged public var id: String
    @NSManaged public var isRead: Bool
    @NSManaged public var link: String
    @NSManaged public var message: String
    @NSManaged public var notificationId: String
    @NSManaged public var receivedAt: Date
    @NSManaged public var reference: String
    @NSManaged public var title: String
}

extension DitoNotificationRecord: Identifiable {}
