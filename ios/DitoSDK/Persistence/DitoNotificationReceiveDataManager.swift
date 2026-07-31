import CoreData
import Foundation

/// Instantâneo imutável de uma linha pendente de `receive-ios-notification`.
///
/// Cada `fetch` abre um contexto de fundo local, de vida curta. Um `NSManagedObject`
/// **não retém o próprio contexto**, então devolvê-lo ao chamador entrega um fault
/// órfão assim que o contexto é liberado — e isso acontece em momento imprevisível.
/// O sintoma: `json` volta nil, o `guard` do reenvio pula a linha em silêncio, e como
/// isso ocorre antes de mexer no contador, a linha nunca é reenviada nem descartada.
/// Fica presa na fila para sempre, e o evento de entrega simplesmente não é reportado.
///
/// `returnsObjectsAsFaults = false` não resolve: quem dispararia o fault é justamente
/// o contexto que já morreu.
struct DitoNotificationReceiveRow: Sendable {
  let id: NSManagedObjectID
  let json: String?
  let retry: Int16
}

struct DitoNotificationReceiveDataManager {

  @discardableResult
  func save(with json: String?, retry: Int16 = 1) -> Bool {
    var success = false
    let semaphore = DispatchSemaphore(value: 0)

    DitoCoreDataManager.shared.performBackgroundTask { context in
      guard
        let row = NSEntityDescription.insertNewObject(
          forEntityName: "NotificationReceive",
          into: context
        ) as? NotificationReceive
      else {
        DitoLogger.error("Failed to create NotificationReceive entity")
        semaphore.signal()
        return
      }

      row.retry = retry
      row.json = json

      do {
        try context.save()
        DitoLogger.information("NotificationReceive Saved Successfully!!!")
        success = true
      } catch {
        DitoLogger.error(
          "Failed to save NotificationReceive: \(error.localizedDescription)"
        )
        success = false
      }
      semaphore.signal()
    }

    semaphore.wait()
    return success
  }

  @discardableResult
  func update(id: NSManagedObjectID, retry: Int16) -> Bool {
    guard let context = DitoCoreDataManager.shared.newBackgroundContext()
    else {
      DitoLogger.error("Failed to create background context for NotificationReceive update")
      return false
    }

    var success = false
    context.performAndWait {
      do {
        guard let row = try context.existingObject(with: id) as? NotificationReceive
        else {
          DitoLogger.error("NotificationReceive with ID not found")
          return
        }

        row.retry = retry

        try context.save()
        DitoLogger.information("NotificationReceive Updated Successfully!!!")
        success = true
      } catch {
        DitoLogger.error(
          "Failed to update NotificationReceive: \(error.localizedDescription)"
        )
        success = false
      }
    }

    return success
  }

  var fetchAll: [DitoNotificationReceiveRow] {
    guard let context = DitoCoreDataManager.shared.newBackgroundContext()
    else {
      DitoLogger.error("Failed to create background context for NotificationReceive fetch")
      return []
    }

    var results: [DitoNotificationReceiveRow] = []
    context.performAndWait {
      let fetchRequest = NSFetchRequest<NotificationReceive>(entityName: "NotificationReceive")
      fetchRequest.returnsObjectsAsFaults = false

      do {
        // Os atributos são copiados aqui, dentro da fila do contexto: fora dela o
        // objeto não serve mais (ver `DitoNotificationReceiveRow`).
        results = try context.fetch(fetchRequest).map {
          DitoNotificationReceiveRow(id: $0.objectID, json: $0.json, retry: $0.retry)
        }
        DitoLogger.information(
          "\(results.count) NotificationReceive row(s) found - Successfully!!!"
        )
      } catch {
        DitoLogger.error(
          "Error fetching NotificationReceive: \(error.localizedDescription)"
        )
      }
    }

    return results
  }

  @discardableResult
  func delete(with id: NSManagedObjectID) -> Bool {
    guard let context = DitoCoreDataManager.shared.newBackgroundContext()
    else {
      DitoLogger.error("Failed to create background context for NotificationReceive delete")
      return false
    }

    var success = false
    context.performAndWait {
      do {
        guard let row = try context.existingObject(with: id) as? NotificationReceive
        else {
          DitoLogger.error("NotificationReceive with ID not found")
          return
        }

        context.delete(row)
        try context.save()
        DitoLogger.information("NotificationReceive Deleted - Successfully!!!")
        success = true
      } catch {
        DitoLogger.error(
          "Error deleting NotificationReceive: \(error.localizedDescription)"
        )
        success = false
      }
    }

    return success
  }
}
