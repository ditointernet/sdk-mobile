import Foundation
import UIKit

enum DitoRouterService {

  case identify(network: String, id: String, data: DitoSignupRequest)
  case track(reference: String, data: DitoEventRequest)
  case register(reference: String, data: DitoTokenRequest)
  case unregister(reference: String, data: DitoTokenRequest)
  case open(notificationId: String, data: DitoNotificationOpenRequest)

  private var baseUrl: String {
    switch self {
    case .identify:
      return "https://login.plataformasocial.com.br/"
    case .track:
      return "https://events.plataformasocial.com.br/"
    case .register, .unregister, .open:
      return "https://notification.plataformasocial.com.br/"
    }
  }

  private enum HTTPMethod {
    case get
    case post

    var value: String {
      switch self {
      case .get: return "GET"
      case .post: return "POST"
      }
    }
  }

  private var method: HTTPMethod {
    switch self {
    case .identify: return .post
    case .track: return .post
    case .register, .unregister, .open:
      return .post
    }
  }

  private var path: String {
    switch self {
    case .identify(let network, let id, _):
      return "users/\(network)/\(id)/signup"
    case .track(let reference, _):
      return "users/\(reference)"
    case .register(let reference, _):
      return "users/\(reference)/mobile-tokens/"
    case .unregister(let reference, _):
      return "users/\(reference)/mobile-tokens/disable/"
    case .open(let notificationId, _):
      return "notifications/\(notificationId)/open/"
    }
  }

  func asURLRequest() throws -> URLRequest {

    let urlString = "\(baseUrl)\(path)"

    guard let url = URL(string: urlString) else {
      throw DitoErrorType.parseUrlFail
    }

    var urlRequest = URLRequest(
      url: url,
      cachePolicy: .reloadIgnoringCacheData,
      timeoutInterval: 10
    )
    urlRequest.httpMethod = method.value
    urlRequest.setValue(
      "application/json",
      forHTTPHeaderField: "Content-Type"
    )
    urlRequest.setValue("iPhone", forHTTPHeaderField: "User-Agent")

    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.outputFormatting = .prettyPrinted

    switch self {
    case .identify(_, _, let data):
      urlRequest.httpBody = try encoder.encode(data)
      return urlRequest
    case .track(_, let data):
      urlRequest.httpBody = try encoder.encode(data)
      return urlRequest
    case .register(_, let data):
      urlRequest.httpBody = try encoder.encode(data)
      return urlRequest
    case .unregister(_, let data):
      urlRequest.httpBody = try encoder.encode(data)
      return urlRequest
    case .open(_, let data):
      urlRequest.httpBody = try encoder.encode(data)
      return urlRequest
    }
  }
}
