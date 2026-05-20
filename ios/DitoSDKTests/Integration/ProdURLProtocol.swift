import Foundation

final class ProdURLProtocol: URLProtocol {
    static var capturedCodes: [Int] = []
    static var capturedCodesLock = NSLock()

    static func reset() {
        capturedCodesLock.lock()
        defer { capturedCodesLock.unlock() }
        capturedCodes = []
    }

    static func lastCode() -> Int {
        capturedCodesLock.lock()
        defer { capturedCodesLock.unlock() }
        return capturedCodes.last ?? -1
    }

    static func allCodes() -> [Int] {
        capturedCodesLock.lock()
        defer { capturedCodesLock.unlock() }
        return capturedCodes
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let config = URLSessionConfiguration.default
        config.protocolClasses = []
        let session = URLSession(configuration: config)
        session.dataTask(with: request) { data, response, error in
            if let http = response as? HTTPURLResponse {
                ProdURLProtocol.capturedCodesLock.lock()
                ProdURLProtocol.capturedCodes.append(http.statusCode)
                ProdURLProtocol.capturedCodesLock.unlock()
            }
            if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
            } else if let response = response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                if let data = data { self.client?.urlProtocol(self, didLoad: data) }
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }.resume()
    }

    override func stopLoading() {}
}
