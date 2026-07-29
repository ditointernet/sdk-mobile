import Foundation

public struct DitoNotificationInfo {
    public let id: String
    public let notificationId: String
    public let reference: String
    public let title: String
    public let message: String
    public let link: String
    public let receivedAt: Date
    public let isRead: Bool
    /// `data.image`, empty when the campaign had no image.
    public let image: String
    /// `data.custom_data`, empty when the campaign had none.
    public let customData: [String: String]

    public init(
        id: String,
        notificationId: String,
        reference: String,
        title: String,
        message: String,
        link: String,
        receivedAt: Date,
        isRead: Bool,
        image: String = "",
        customData: [String: String] = [:]
    ) {
        self.id = id
        self.notificationId = notificationId
        self.reference = reference
        self.title = title
        self.message = message
        self.link = link
        self.receivedAt = receivedAt
        self.isRead = isRead
        self.image = image
        self.customData = customData
    }
}
