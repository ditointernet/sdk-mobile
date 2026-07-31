import DitoSDKNotificationService

// Re-exports the shared rich-push types so app targets keep needing a single
// `import DitoSDK`.
//
// Typealiases rather than `@_exported import`: that attribute is underscored and
// unsupported, and it does not carry through a `.swiftinterface`, so it would
// silently stop re-exporting the day this framework is built with library
// evolution enabled.
//
// Only a Notification Service Extension target imports
// `DitoSDKNotificationService` directly; the full SDK cannot be linked there
// because it uses app-only API (see `UIApplication` in `Dito.swift`).

public typealias DitoPushAction = DitoSDKNotificationService.DitoPushAction
public typealias DitoRichPushPayload = DitoSDKNotificationService.DitoRichPushPayload
public typealias DitoRichPushKeys = DitoSDKNotificationService.DitoRichPushKeys
public typealias DitoPushDebugLog = DitoSDKNotificationService.DitoPushDebugLog
public typealias DitoPushLogSource = DitoSDKNotificationService.DitoPushLogSource
public typealias DitoPushLogEvent = DitoSDKNotificationService.DitoPushLogEvent
