import Foundation
import UniformTypeIdentifiers
import UserNotifications

/// Base class for a Dito Notification Service Extension.
///
/// Integrators add a Notification Service Extension target to their app and make
/// its principal class inherit from this one:
///
///     import DitoSDKNotificationService
///
///     class NotificationService: DitoNotificationService {}
///
/// It attaches `data.image` as an `UNNotificationAttachment` and registers a
/// `UNNotificationCategory` whose actions are the `data.actions` buttons.
///
/// This type is deliberately extension-safe: it links only Foundation,
/// UserNotifications and UniformTypeIdentifiers, and never touches CoreData,
/// UIKit or `UIApplication`.
///
/// Nothing here is required for a push to be delivered. Without the extension the
/// notification still renders as title + body; only the image and buttons are lost.
open class DitoNotificationService: UNNotificationServiceExtension {

  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttemptContent: UNMutableNotificationContent?
  private let hasDelivered = DitoAtomicFlag()

  /// Budget for the image download. The system allows the extension ~30s in
  /// total; staying well under it leaves room to still deliver the text content.
  open var imageDownloadTimeout: TimeInterval { 15 }

  open override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler

    let userInfo = request.content.userInfo
    DitoPushDebugLog.dump(source: .notificationServiceExtension, userInfo: userInfo)

    guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
      deliver(request.content)
      return
    }
    self.bestAttemptContent = content

    let payload = DitoRichPushPayload(userInfo: userInfo)
    guard !payload.isEmpty else {
      deliver(content)
      return
    }

    let attachmentBox = DitoAttachmentBox()
    let group = DispatchGroup()

    if let categoryIdentifier = payload.categoryIdentifier {
      group.enter()
      Self.registerCategory(identifier: categoryIdentifier, actions: payload.actions) {
        group.leave()
      }
    }

    if let imageURL = payload.imageURL {
      group.enter()
      Self.downloadAttachment(from: imageURL, timeout: imageDownloadTimeout) { attachment in
        attachmentBox.value = attachment
        group.leave()
      }
    }

    // Mutating `content` only here keeps a single writer, whichever order the
    // two asynchronous branches finish in.
    group.notify(queue: .main) { [weak self] in
      guard let self else { return }
      if let categoryIdentifier = payload.categoryIdentifier {
        content.categoryIdentifier = categoryIdentifier
      }
      if let attachment = attachmentBox.value {
        content.attachments = [attachment]
      }
      self.deliver(content)
    }
  }

  open override func serviceExtensionTimeWillExpire() {
    // Out of time: hand back whatever we managed to build.
    deliver(bestAttemptContent)
  }

  /// Calls the system handler at most once.
  private func deliver(_ content: UNNotificationContent?) {
    guard hasDelivered.setIfUnset() else { return }
    guard let handler = contentHandler, let content else { return }
    contentHandler = nil
    handler(content)
  }
}

// MARK: - Category registration

extension DitoNotificationService {

  /// Registers (or refreshes) the category carrying this push's buttons.
  ///
  /// Existing categories are preserved: the app may register its own, and
  /// `setNotificationCategories` replaces the whole set.
  static func registerCategory(
    identifier: String,
    actions: [DitoPushAction],
    completion: @escaping () -> Void
  ) {
    let center = UNUserNotificationCenter.current()
    let notificationActions = actions.map { action in
      UNNotificationAction(
        identifier: action.id,
        title: action.label,
        // `.foreground` so the app is brought up to handle the button's deeplink.
        options: [.foreground]
      )
    }
    let category = UNNotificationCategory(
      identifier: identifier,
      actions: notificationActions,
      intentIdentifiers: [],
      options: []
    )

    center.getNotificationCategories { existing in
      var merged = existing.filter { $0.identifier != identifier }
      merged.insert(category)
      center.setNotificationCategories(merged)
      completion()
    }
  }
}

// MARK: - Image download

extension DitoNotificationService {

  static func downloadAttachment(
    from url: URL,
    timeout: TimeInterval,
    completion: @escaping (UNNotificationAttachment?) -> Void
  ) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout
    let session = URLSession(configuration: configuration)

    let task = session.downloadTask(with: url) { location, response, _ in
      defer { session.finishTasksAndInvalidate() }
      guard let location else {
        completion(nil)
        return
      }
      if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        completion(nil)
        return
      }
      completion(makeAttachment(from: location, url: url, response: response))
    }
    task.resume()
  }

  /// `UNNotificationAttachment` validates by file extension, so the downloaded
  /// temp file has to be renamed to something the system recognises.
  private static func makeAttachment(
    from location: URL,
    url: URL,
    response: URLResponse?
  ) -> UNNotificationAttachment? {
    let fileExtension = resolveFileExtension(url: url, response: response)
    let destination = FileManager.default.temporaryDirectory
      .appendingPathComponent("dito-push-\(UUID().uuidString)")
      .appendingPathExtension(fileExtension)

    do {
      try FileManager.default.moveItem(at: location, to: destination)
      return try UNNotificationAttachment(identifier: "dito.image", url: destination, options: nil)
    } catch {
      try? FileManager.default.removeItem(at: destination)
      return nil
    }
  }

  private static func resolveFileExtension(url: URL, response: URLResponse?) -> String {
    let pathExtension = url.pathExtension.lowercased()
    if !pathExtension.isEmpty, UTType(filenameExtension: pathExtension)?.conforms(to: .image) == true {
      return pathExtension
    }
    if let mimeType = response?.mimeType,
       let type = UTType(mimeType: mimeType),
       let preferred = type.preferredFilenameExtension {
      return preferred
    }
    return "png"
  }
}

// MARK: - Small concurrency helpers

/// One-shot flag guarding against calling the content handler twice
/// (`didReceive` finishing and `serviceExtensionTimeWillExpire` racing).
final class DitoAtomicFlag: @unchecked Sendable {

  private let lock = NSLock()
  private var isSet = false

  /// Sets the flag, returning `true` only for the first caller.
  func setIfUnset() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    if isSet { return false }
    isSet = true
    return true
  }
}

/// Transfers the downloaded attachment between the download callback and
/// `DispatchGroup.notify`.
final class DitoAttachmentBox: @unchecked Sendable {

  private let lock = NSLock()
  private var storage: UNNotificationAttachment?

  var value: UNNotificationAttachment? {
    get {
      lock.lock()
      defer { lock.unlock() }
      return storage
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      storage = newValue
    }
  }
}
