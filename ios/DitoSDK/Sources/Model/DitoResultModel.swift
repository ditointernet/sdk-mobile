import Foundation

struct DitoResultModel<T: Decodable>: Decodable {
  var data: T?
}
