import XCTest
@testable import DitoSDK

class DitoServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        setupTestEnvironment()
    }

    override func tearDown() {
        teardownTestEnvironment()
        super.tearDown()
    }

    func testDitoRouterService_IdentifyURL_IsCorrect() {
        let signupRequest = DitoSignupRequest(
            platformAppKey: "test_key",
            sha1Signature: "test_sig",
            userData: nil
        )

        let router = DitoRouterService.identify(
            network: "portal",
            id: "user123",
            data: signupRequest
        )

        guard let urlRequest = try? router.asURLRequest() else {
            XCTFail("Failed to create URL request")
            return
        }

        XCTAssertEqual(
            urlRequest.url?.absoluteString,
            "https://login.plataformasocial.com.br/users/portal/user123/signup"
        )
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testDitoRouterService_TrackURL_IsCorrect() {
        let event = DitoEvent(action: "test_action")
        let eventRequest = DitoEventRequest(
            platformAppKey: "test_key",
            sha1Signature: "test_sig",
            event: event
        )

        let router = DitoRouterService.track(
            reference: "ref123",
            data: eventRequest
        )

        guard let urlRequest = try? router.asURLRequest() else {
            XCTFail("Failed to create URL request")
            return
        }

        XCTAssertEqual(
            urlRequest.url?.absoluteString,
            "https://events.plataformasocial.com.br/users/ref123"
        )
        XCTAssertEqual(urlRequest.httpMethod, "POST")
    }

    func testDitoRouterService_RegisterTokenURL_IsCorrect() {
        let tokenRequest = DitoTokenRequest(
            platformAppKey: "test_key",
            sha1Signature: "test_sig",
            token: "fcm_token"
        )

        let router = DitoRouterService.register(
            reference: "ref123",
            data: tokenRequest
        )

        guard let urlRequest = try? router.asURLRequest() else {
            XCTFail("Failed to create URL request")
            return
        }

        XCTAssertEqual(
            urlRequest.url?.absoluteString,
            "https://notification.plataformasocial.com.br/users/ref123/mobile-tokens/"
        )
        XCTAssertEqual(urlRequest.httpMethod, "POST")
    }

    func testDitoRouterService_UnregisterTokenURL_HasTrailingSlash() {
        let tokenRequest = DitoTokenRequest(
            platformAppKey: "test_key",
            sha1Signature: "test_sig",
            token: "fcm_token"
        )

        let router = DitoRouterService.unregister(
            reference: "ref123",
            data: tokenRequest
        )

        guard let urlRequest = try? router.asURLRequest() else {
            XCTFail("Failed to create URL request")
            return
        }

        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertTrue(
            urlString.hasSuffix("/disable/"),
            "Unregister endpoint must have trailing slash"
        )
    }

    func testDitoRouterService_HTTPBodyIsEncoded() {
        let event = DitoEvent(action: "test_action", revenue: 100.0)
        let eventRequest = DitoEventRequest(
            platformAppKey: "test_key",
            sha1Signature: "test_sig",
            event: event
        )

        let router = DitoRouterService.track(
            reference: "ref123",
            data: eventRequest
        )

        guard let urlRequest = try? router.asURLRequest(),
              let httpBody = urlRequest.httpBody else {
            XCTFail("Failed to create URL request with body")
            return
        }

        XCTAssertFalse(httpBody.isEmpty, "HTTP body should not be empty")

        guard let jsonObject = try? JSONSerialization.jsonObject(with: httpBody) as? [String: Any] else {
            XCTFail("Failed to parse HTTP body as JSON")
            return
        }

        XCTAssertNotNil(jsonObject["platform_api_key"])
        XCTAssertNotNil(jsonObject["sha1_signature"])
        XCTAssertNotNil(jsonObject["event"])
    }

    func testDitoRouterService_Headers_AreSetCorrectly() {
        let signupRequest = DitoSignupRequest(
            platformAppKey: "test_key",
            sha1Signature: "test_sig",
            userData: nil
        )

        let router = DitoRouterService.identify(
            network: "portal",
            id: "user123",
            data: signupRequest
        )

        guard let urlRequest = try? router.asURLRequest() else {
            XCTFail("Failed to create URL request")
            return
        }

        XCTAssertEqual(
            urlRequest.value(forHTTPHeaderField: "Content-Type"),
            "application/json"
        )
        XCTAssertEqual(
            urlRequest.value(forHTTPHeaderField: "User-Agent"),
            "iPhone"
        )
    }

    func testDitoRouterService_Timeout_IsSetCorrectly() {
        let signupRequest = DitoSignupRequest(
            platformAppKey: "test_key",
            sha1Signature: "test_sig",
            userData: nil
        )

        let router = DitoRouterService.identify(
            network: "portal",
            id: "user123",
            data: signupRequest
        )

        guard let urlRequest = try? router.asURLRequest() else {
            XCTFail("Failed to create URL request")
            return
        }

        XCTAssertEqual(urlRequest.timeoutInterval, 10)
    }

    func testDitoRouterService_CachePolicy_IsSetCorrectly() {
        let signupRequest = DitoSignupRequest(
            platformAppKey: "test_key",
            sha1Signature: "test_sig",
            userData: nil
        )

        let router = DitoRouterService.identify(
            network: "portal",
            id: "user123",
            data: signupRequest
        )

        guard let urlRequest = try? router.asURLRequest() else {
            XCTFail("Failed to create URL request")
            return
        }

        XCTAssertEqual(urlRequest.cachePolicy, .reloadIgnoringCacheData)
    }

    func testDitoEventRequest_SerializesEventAsObject() {
        let event = DitoEvent(
            action: "purchase",
            revenue: 99.99,
            customData: ["product_id": "123"]
        )

        let eventRequest = DitoEventRequest(
            platformAppKey: "test_key",
            sha1Signature: "test_sig",
            event: event
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        guard let jsonData = try? encoder.encode(eventRequest),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let eventObject = jsonObject["event"] as? [String: Any] else {
            XCTFail("Failed to encode or parse event request")
            return
        }

        XCTAssertTrue(eventObject is [String: Any], "Event should be an object")
        XCTAssertEqual(eventObject["action"] as? String, "purchase")
        XCTAssertEqual(eventObject["revenue"] as? Double, 99.99)
    }

    func testDitoTokenRequest_HasAllRequiredFields() {
        let tokenRequest = DitoTokenRequest(
            platformAppKey: "test_key",
            sha1Signature: "test_sig",
            token: "fcm_token"
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        guard let jsonData = try? encoder.encode(tokenRequest),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Failed to encode token request")
            return
        }

        XCTAssertNotNil(jsonObject["platform_api_key"])
        XCTAssertNotNil(jsonObject["sha1_signature"])
        XCTAssertNotNil(jsonObject["token"])
        XCTAssertNotNil(jsonObject["platform"])
        XCTAssertNotNil(jsonObject["id_type"])
        XCTAssertNotNil(jsonObject["encoding"], "encoding field is required for Android compatibility")

        XCTAssertNil(jsonObject["ios_token_type"], "ios_token_type should not be present")
    }

    func testDitoSignupRequest_Encoding() {
        let user = DitoUser(
            name: "Test User",
            email: "test@example.com"
        )

        let signupRequest = DitoSignupRequest(
            platformAppKey: "test_key",
            sha1Signature: "test_sig",
            userData: user
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        guard let jsonData = try? encoder.encode(signupRequest),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Failed to encode signup request")
            return
        }

        XCTAssertNotNil(jsonObject["platform_api_key"])
        XCTAssertNotNil(jsonObject["sha1_signature"])
        XCTAssertNotNil(jsonObject["user_data"])
        XCTAssertNotNil(jsonObject["encoding"])

        XCTAssertEqual(jsonObject["encoding"] as? String, "base64")
    }
}
