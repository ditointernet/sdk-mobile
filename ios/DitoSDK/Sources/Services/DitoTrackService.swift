import Foundation

class DitoTrackService: DitoServiceManager {

  func event(
    reference: String,
    data: DitoEventRequest,
    completion:
      @escaping (_ success: [DitoTrackModel]?, _ error: Error?) -> Void
  ) {

    request(
      type: [DitoTrackModel].self,
      router: .track(reference: reference, data: data)
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
