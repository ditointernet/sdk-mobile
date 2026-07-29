// Re-exports the extension-safe module so that app targets keep needing a
// single `import DitoSDK` to reach the shared rich-push types
// (`DitoPushAction`, `DitoRichPushPayload`, `DitoPushDebugLog`).
//
// Only a Notification Service Extension target imports
// `DitoSDKNotificationService` directly; the full SDK cannot be linked there
// because it uses app-only API (see `UIApplication` in `Dito.swift`).
@_exported import DitoSDKNotificationService
