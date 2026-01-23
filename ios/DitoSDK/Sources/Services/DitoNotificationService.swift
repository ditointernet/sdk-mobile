import Foundation

class DitoNotificationService: DitoServiceManager {

  func register(
    reference: String, data: DitoTokenRequest,
    completion: @escaping (_ success: DitoTokenModel?, _ error: Error?) -> Void
  ) {
    request(type: DitoTokenModel.self, router: .register(reference: reference, data: data)) {
      result in

      switch result {
      case .success(let data):
        completion(data, nil)
      case .failure(let error):
        completion(nil, error)
      }
    }
  }

  func unregister(
    reference: String, data: DitoTokenRequest,
    completion: @escaping (_ success: DitoTokenModel?, _ error: Error?) -> Void
  ) {

    request(type: DitoTokenModel.self, router: .unregister(reference: reference, data: data)) {
      result in

      switch result {
      case .success(let data):
        completion(data, nil)
      case .failure(let error):
        completion(nil, error)
      }
    }
  }

  func read(
    notificationId: String, data: DitoNotificationOpenRequest,
    completion: @escaping (_ success: DitoIdentifyModel?, _ error: Error?) -> Void
  ) {

    request(type: DitoIdentifyModel.self, router: .open(notificationId: notificationId, data: data))
    { result in

      switch result {
      case .success(let data):
        completion(data, nil)
      case .failure(let error):
        completion(nil, error)
      }
    }
  }
}
