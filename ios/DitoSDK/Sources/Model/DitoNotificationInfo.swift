import Foundation

public struct DitoNotificationInfo {
    public let id: String
    public let notificationId: String
    public let title: String
    public let message: String
    public let link: String
    public let receivedAt: Date
    public let isRead: Bool
    /// `data.image`, empty when the campaign had no image.
    public let image: String
    /// `data.custom_data`, empty when the campaign had none.
    public let customData: [String: String]

    /// Always empty.
    ///
    /// The `reference` field is being retired from Dito payloads and the SDK no
    /// longer reads it; attribution anchors on `user_id`. Kept as a computed
    /// property so existing call sites keep compiling while the compiler points
    /// integrators at the migration.
    @available(*, deprecated, message: "reference was retired from Dito payloads; anchor on user_id. Always empty.")
    public var reference: String { "" }

    /// - Parameter reference: ignored; accepted so existing call sites still compile.
    public init(
        id: String,
        notificationId: String,
        reference: String = "",
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
        self.title = title
        self.message = message
        self.link = link
        self.receivedAt = receivedAt
        self.isRead = isRead
        self.image = image
        self.customData = customData
    }
}
