import XCTest
@testable import DitoSDK

private final class AuthStubURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var _captured: URLRequest?

    static var capturedRequest: URLRequest? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _captured
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _captured = newValue
        }
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        _captured = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.capturedRequest = request
        let body: Data
        do {
            body = try Mobileingest_V1_Response().serializedData()
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/proto",
                "Content-Length": "\(body.count)",
            ]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func headerValue(_ name: String, in request: URLRequest) -> String? {
    guard let fields = request.allHTTPHeaderFields else { return nil }
    let lower = name.lowercased()
    return fields.first { $0.key.lowercased() == lower }?.value
}

final class MobileIngestAuthTests: XCTestCase {

    override func tearDown() {
        AuthStubURLProtocol.reset()
        super.tearDown()
    }

    private func sessionConfigWithStub() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthStubURLProtocol.self] + (config.protocolClasses ?? [])
        return config
    }

    func testLegacyAuth_sendsPlatformApiKeyAndSha1SignatureHeaders() async throws {
        let apiKey = "unit-test-platform-key"
        let sha1 = "unit-test-sha1-signature"
        let client = MobileIngestClient.withLegacyAuth(
            apiKey: apiKey,
            sha1Signature: sha1,
            urlSessionConfiguration: sessionConfigWithStub()
        )
        _ = try await client.activity(Mobileingest_V1_Request())
        let req = try XCTUnwrap(AuthStubURLProtocol.capturedRequest)
        XCTAssertEqual(headerValue("platform_api_key", in: req), apiKey)
        XCTAssertEqual(headerValue("sha1_signature", in: req), sha1)
    }

    func testApiKeyAuth_sendsXApiKeyAndBundleIdHeaders() async throws {
        let apiKey = "unit-test-x-api-key"
        let bundleId = "br.com.dito.unit.tests"
        let client = MobileIngestClient.withApiKey(
            apiKey,
            bundleId: bundleId,
            urlSessionConfiguration: sessionConfigWithStub()
        )
        _ = try await client.activity(Mobileingest_V1_Request())
        let req = try XCTUnwrap(AuthStubURLProtocol.capturedRequest)
        XCTAssertEqual(headerValue("X-Api-Key", in: req), apiKey)
        XCTAssertEqual(headerValue("Bundle-Id", in: req), bundleId)
    }
}
