import Foundation

extension Encodable {

  var toString: String? {

    do {
      let jsonData = try JSONEncoder().encode(self)
      return String(data: jsonData, encoding: .utf8).unwrappedValue
    } catch let error {
      DitoLogger.error(error)
      return nil
    }
  }
}
