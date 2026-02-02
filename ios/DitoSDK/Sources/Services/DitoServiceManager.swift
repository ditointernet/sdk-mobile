//
//  DTServiceManager.swift
//  DitoSDK
//
//  Created by Rodrigo Damacena Gamarra Maciel on 21/12/20.
//

import Foundation

class DitoServiceManager {

  private let config: URLSessionConfiguration
  private let session: URLSession

  init() {
    config = URLSessionConfiguration.default
    session = URLSession(configuration: config)
  }

  func request<T: Decodable>(
    type: T.Type,
    router: DitoRouterService,
    completion: @escaping NetworkCompletion<T>
  ) {
    do {
      let urlRequest = try router.asURLRequest()

      logRequest(urlRequest)

      let task = try session.dataTask(with: urlRequest) {
        (data, response, error) in
        DispatchQueue.main.async {

          guard let statusCode: Int = response?.getStatusCode else {
            #if DEBUG
            DitoLogger.error("❌ [DITO SDK RESPONSE] No connectivity - Status code unavailable")
            #endif
            return completion(.failure(error: .noConnectivity))
          }

          self.logResponse(request: urlRequest, statusCode: statusCode, data: data, error: error)

          if let error = error {
            completion(.failure(error: .defaultError(error)))
          }

          guard let data = data else {
            return completion(.failure(error: .unknown))
          }

          guard let json = data.convertToJson(type: T.self) else {
            return completion(.failure(error: .invalidJSON))
          }

          switch statusCode {
          case 200...299:
            completion(.success(data: json))
          case 500...599:
            completion(.failure(error: .serverError))
          default:
            completion(.failure(error: .unknown))

          }
        }
      }
      task.resume()

    } catch let error {
      #if DEBUG
      DitoLogger.error("❌ [DITO SDK REQUEST] Failed to create request: \(error.localizedDescription)")
      #endif
      completion(.failure(error: .defaultError(error)))
    }
  }

  private func logRequest(_ request: URLRequest) {
    #if DEBUG
    guard let url = request.url,
          let method = request.httpMethod else {
      DitoLogger.warning("🌐 [DITO SDK REQUEST] Invalid request")
      return
    }

    print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    DitoLogger.debug("📤 [REQUEST] \(method) \(url.absoluteString)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
      print("📋 Headers:")
      for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
        print("   • \(key): \(value)")
      }
    }

    if let httpBody = request.httpBody {
      let bodySize = ByteCountFormatter.string(fromByteCount: Int64(httpBody.count), countStyle: .binary)
      print("\n📦 Body (\(bodySize)):")

      if let bodyString = String(data: httpBody, encoding: .utf8) {
        print(bodyString)
      } else {
        print("⚠️ Body is not valid UTF-8 string")
      }
    }
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    #endif
  }

  private func logResponse(request: URLRequest, statusCode: Int, data: Data?, error: Error?) {
    #if DEBUG
    let url = request.url?.absoluteString ?? "unknown"
    let statusEmoji = getStatusEmoji(statusCode: statusCode)
    let statusDescription = getStatusDescription(statusCode: statusCode)

    print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    DitoLogger.debug("\(statusEmoji) [RESPONSE] \(statusCode) \(statusDescription)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📍 URL: \(url)")

    if let error = error {
      print("❌ Error: \(error.localizedDescription)")
    }

    if let data = data {
      let bodySize = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .binary)
      print("\n📦 Body (\(bodySize)):")

      if let bodyString = String(data: data, encoding: .utf8) {
        print(bodyString)
      } else {
        print("⚠️ Body is not valid UTF-8 string")
      }
    } else {
      print("\n📦 Body: (empty)")
    }
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    #endif
  }

  private func getStatusEmoji(statusCode: Int) -> String {
    switch statusCode {
    case 200...299: return "✅"
    case 300...399: return "↪️"
    case 400...499: return "⚠️"
    case 500...599: return "❌"
    default: return "❓"
    }
  }

  private func getStatusDescription(statusCode: Int) -> String {
    switch statusCode {
    case 200: return "OK"
    case 201: return "Created"
    case 204: return "No Content"
    case 400: return "Bad Request"
    case 401: return "Unauthorized"
    case 403: return "Forbidden"
    case 404: return "Not Found"
    case 500: return "Internal Server Error"
    case 502: return "Bad Gateway"
    case 503: return "Service Unavailable"
    default: return "HTTP \(statusCode)"
    }
  }
}
