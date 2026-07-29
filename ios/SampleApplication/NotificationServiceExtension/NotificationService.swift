import DitoSDKNotificationService

/// Sample Notification Service Extension.
///
/// Everything needed for rich push (image attachment + action buttons) lives in
/// `DitoNotificationService`; subclassing is the whole integration.
///
/// Note this target links `DitoSDKNotificationService`, never the full `DitoSDK`:
/// the SDK proper uses `UIApplication` and CoreData, which are unavailable in an
/// app extension.
class NotificationService: DitoNotificationService {}
