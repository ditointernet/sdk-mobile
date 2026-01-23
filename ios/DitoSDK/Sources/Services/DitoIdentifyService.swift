import Foundation

class DitoIdentifyService: DitoServiceManager {

  func signup(
    network: String,
    id: String,
    data: DitoSignupRequest,
    completion:
      @escaping (_ success: DitoIdentifyModel?, _ error: Error?) -> Void
  ) {

    request(
      type: DitoIdentifyModel.self,
      router: .identify(network: network, id: id, data: data)
    ) { result in

      switch result {
      case .success(let data):
        completion(data, nil)
      case .failure(let error):
        completion(nil, error)
      }
    }
  }

}
