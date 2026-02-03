import CoreData
import Foundation

class DitoCoreDataManager {

  nonisolated(unsafe) static let shared = DitoCoreDataManager()

  private let model: String = "DitoDataModel"
  private let persistentContainerQueue = DispatchQueue(label: "br.com.dito.coredata.container")
  private var storedPersistentContainer: NSPersistentContainer?
  var persistentContainer: NSPersistentContainer? {
    return persistentContainerQueue.sync {
      if let container = storedPersistentContainer {
        return container
      }
      let container = createPersistentContainer()
      storedPersistentContainer = container
      return container
    }
  }

  var viewContext: NSManagedObjectContext? {
    return persistentContainer?.viewContext
  }

  private init() {
  }

  private func createPersistentContainer() -> NSPersistentContainer? {
    guard
      let frameworkBundle = Bundle(for: type(of: self)).url(
        forResource: self.model,
        withExtension: "momd"
      ),
      let managedObjectModel = NSManagedObjectModel(
        contentsOf: frameworkBundle
      )
    else {
      DitoLogger.error("Failed to load Core Data model '\(self.model)'")
      return nil
    }

    let container = NSPersistentContainer(
      name: self.model,
      managedObjectModel: managedObjectModel
    )

    if let storeURL = FileManager.default
      .urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first?
      .appendingPathComponent("\(self.model).sqlite")
    {
      try? FileManager.default.createDirectory(
        at: storeURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let description = NSPersistentStoreDescription(url: storeURL)
      description.setOption(
        true as NSNumber,
        forKey: NSPersistentHistoryTrackingKey
      )
      description.setOption(
        true as NSNumber,
        forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
      )
      container.persistentStoreDescriptions = [description]
    } else {
      let description = container.persistentStoreDescriptions.first
      description?.setOption(
        true as NSNumber,
        forKey: NSPersistentHistoryTrackingKey
      )
      description?.setOption(
        true as NSNumber,
        forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
      )
    }

    var loadError: Error?
    let semaphore = DispatchSemaphore(value: 0)

    container.loadPersistentStores { (storeDescription, error) in
      if let error = error {
        DitoLogger.error(
          "Failed to load persistent store: \(error.localizedDescription)"
        )
        loadError = error
      } else {
        DitoLogger.information("Persistent store loaded successfully")
      }
      semaphore.signal()
    }

    semaphore.wait()

    if loadError != nil {
      return nil
    }

    container.viewContext.automaticallyMergesChangesFromParent = true

    container.viewContext.undoManager = nil
    container.viewContext.shouldDeleteInaccessibleFaults = true

    return container
  }

  func performBackgroundTask(
    _ block: @escaping (NSManagedObjectContext) -> Void
  ) {
    guard let container = persistentContainer else {
      DitoLogger.error(
        "Cannot perform background task: persistent container not available"
      )
      return
    }
    container.performBackgroundTask(block)
  }

  func newBackgroundContext() -> NSManagedObjectContext? {
    guard let container = persistentContainer else {
      DitoLogger.error(
        "Cannot create background context: persistent container not available"
      )
      return nil
    }
    let context = container.newBackgroundContext()
    context.undoManager = nil
    return context
  }
}

struct NotificationDefaults: Codable {
  var retry: Int16
  var json: String?
}

struct IdentifyDefaults: Codable {
  var id: String?
  var json: String?
  var reference: String?
  var send: Bool
}
