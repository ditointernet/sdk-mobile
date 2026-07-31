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

  /// `didReceive`, the `DispatchGroup` completion and
  /// `serviceExtensionTimeWillExpire` all run on different threads, so every piece
  /// of delivery state lives behind one lock rather than in bare properties.
  private let state = DitoDeliveryState()

  /// Budget for the image download. The system allows the extension ~30s in
  /// total; staying well under it leaves room to still deliver the text content.
  open var imageDownloadTimeout: TimeInterval { 15 }

  /// Largest image accepted. `UNNotificationAttachment` rejects images past
  /// roughly this size anyway, so a bigger download can only waste the
  /// extension's time budget.
  open var maxImageBytes: Int { 10 * 1024 * 1024 }

  open override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    state.begin(handler: contentHandler)

    let userInfo = request.content.userInfo
    DitoPushDebugLog.dump(event: .received, source: .notificationServiceExtension, userInfo: userInfo)

    guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
      state.deliver(request.content)
      return
    }
    state.setBestAttempt(content)

    let payload = DitoRichPushPayload(userInfo: userInfo)
    guard !payload.isEmpty else {
      state.deliver(content)
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
      Self.downloadAttachment(
        from: imageURL,
        timeout: imageDownloadTimeout,
        maxBytes: maxImageBytes
      ) { attachment in
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
      self.state.deliver(content)
    }
  }

  open override func serviceExtensionTimeWillExpire() {
    // Out of time: hand back whatever we managed to build.
    state.deliver(nil)
  }
}

// MARK: - Delivery state

/// Owns the system content handler and the best attempt built so far.
///
/// The handler doubles as the one-shot guard: it is cleared only when a delivery
/// actually happens, so a call that has nothing to hand back cannot consume the
/// single delivery and leave the notification silently dropped.
private final class DitoDeliveryState: @unchecked Sendable {

  private let lock = NSLock()
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttempt: UNMutableNotificationContent?

  func begin(handler: @escaping (UNNotificationContent) -> Void) {
    lock.lock()
    defer { lock.unlock() }
    contentHandler = handler
  }

  func setBestAttempt(_ content: UNMutableNotificationContent) {
    lock.lock()
    defer { lock.unlock() }
    bestAttempt = content
  }

  /// Delivers `content`, falling back to the best attempt so far when it is nil.
  /// Only the first effective call reaches the system handler.
  func deliver(_ content: UNNotificationContent?) {
    lock.lock()
    guard let handler = contentHandler, let delivered = content ?? bestAttempt else {
      lock.unlock()
      return
    }
    contentHandler = nil
    lock.unlock()
    // Called outside the lock: the system handler is not ours and must not run
    // with a lock held.
    handler(delivered)
  }
}

// MARK: - Category registration

extension DitoNotificationService {

  /// Prefix owned by the SDK. Categories registered by the host app never carry
  /// it and are therefore never touched.
  static let categoryPrefix = "dito.actions."

  /// Registers (or refreshes) the category carrying this push's buttons.
  ///
  /// Three things have to be true when `completion` runs:
  ///
  /// - categories the host app registered itself survive — `setNotificationCategories`
  ///   replaces the whole set, so the existing set is read and merged;
  /// - SDK categories that no delivered notification still references are dropped,
  ///   so the set does not grow once per campaign forever;
  /// - the daemon has actually stored the category. `setNotificationCategories`
  ///   is asynchronous and offers no completion handler, so a second
  ///   `getNotificationCategories` is used as a round-trip barrier: it is served
  ///   by the same connection and therefore lands after the write. Delivering
  ///   without it renders the push with no buttons.
  static func registerCategory(
    identifier: String,
    actions: [DitoPushAction],
    completion: @escaping () -> Void
  ) {
    let center = UNUserNotificationCenter.current()
    let category = UNNotificationCategory(
      identifier: identifier,
      actions: actions.map { action in
        UNNotificationAction(
          identifier: action.id,
          title: action.label,
          // `.foreground` so the app is brought up to handle the button's deeplink.
          options: [.foreground]
        )
      },
      intentIdentifiers: [],
      options: []
    )

    center.getDeliveredNotifications { delivered in
      let stillOnScreen = Set(delivered.map { $0.request.content.categoryIdentifier })
      center.getNotificationCategories { existing in
        var merged = prune(existing, refreshing: identifier, stillOnScreen: stillOnScreen)
        merged.insert(category)
        center.setNotificationCategories(merged)
        center.getNotificationCategories { _ in completion() }
      }
    }
  }

  /// Drops the SDK's own stale categories, keeping everything else untouched.
  ///
  /// A category is stale when it belongs to the SDK, is not the one being
  /// refreshed, and no notification currently in Notification Center uses it —
  /// pruning one that is still on screen would strip that notification's buttons.
  static func prune(
    _ existing: Set<UNNotificationCategory>,
    refreshing identifier: String,
    stillOnScreen: Set<String>
  ) -> Set<UNNotificationCategory> {
    existing.filter { category in
      guard category.identifier.hasPrefix(categoryPrefix) else { return true }
      guard category.identifier != identifier else { return false }
      return stillOnScreen.contains(category.identifier)
    }
  }
}

// MARK: - Image download

extension DitoNotificationService {

  static func downloadAttachment(
    from url: URL,
    timeout: TimeInterval,
    maxBytes: Int,
    completion: @escaping (UNNotificationAttachment?) -> Void
  ) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = timeout
    // Also bounds how much can be transferred: an oversized image runs out of
    // time here rather than eating the extension's whole budget.
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
      completion(makeAttachment(from: location, url: url, response: response, maxBytes: maxBytes))
    }
    task.resume()
  }

  /// `UNNotificationAttachment` validates by file extension, so the downloaded
  /// temp file has to be renamed to something the system recognises.
  static func makeAttachment(
    from location: URL,
    url: URL,
    response: URLResponse?,
    maxBytes: Int
  ) -> UNNotificationAttachment? {
    guard fileSize(at: location).map({ $0 <= maxBytes }) ?? true else {
      try? FileManager.default.removeItem(at: location)
      return nil
    }

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

  /// Resolves the extension `UNNotificationAttachment` will validate against.
  ///
  /// The URL's own extension wins when it names an image type; otherwise the
  /// response's MIME type decides; `png` is the last resort, since an attachment
  /// with no usable extension is rejected outright.
  static func resolveFileExtension(url: URL, response: URLResponse?) -> String {
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

  private static func fileSize(at url: URL) -> Int? {
    (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int
  }
}

// MARK: - Small concurrency helpers

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
