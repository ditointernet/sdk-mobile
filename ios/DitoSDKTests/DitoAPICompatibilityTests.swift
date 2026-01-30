import XCTest
@testable import DitoSDK

class DitoAPICompatibilityTests: XCTestCase {

    func testDitoRouterService_UnregisterEndpoint_HasTrailingSlash() {
        let router = DitoRouterService.unregister(
            reference: "test_ref",
            data: DitoTokenRequest(
                platformApiKey: "test_key",
                sha1Signature: "test_sig",
                token: "test_token"
            )
        )

        guard let urlRequest = try? router.asURLRequest() else {
            XCTFail("Failed to create URL request")
            return
        }

        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertTrue(
            urlString.hasSuffix("/mobile-tokens/disable/"),
            "Unregister endpoint must end with trailing slash to match Android. Got: \(urlString)"
        )
    }

    func testDitoRouterService_OpenNotificationEndpoint_HasTrailingSlash() {
        let router = DitoRouterService.open(
            notificationId: "notif_123",
            data: DitoNotificationOpenRequest(
                platformApiKey: "test_key",
                sha1Signature: "test_sig",
                data: DitoDataNotification(
                    identifier: "123",
                    reference: "ref_123",
                    notification: "notif_123",
                    notificationLogId: "log_123",
                    userId: "user_123",
                    deviceType: "iPhone",
                    channel: "DITO",
                    notificationName: "Test",
                    title: "Title",
                    message: "Message",
                    link: "app://link",
                    logId: "log_123"
                )
            )
        )

        guard let urlRequest = try? router.asURLRequest() else {
            XCTFail("Failed to create URL request")
            return
        }

        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertTrue(
            urlString.hasSuffix("/open/"),
            "Open notification endpoint must end with trailing slash to match Android. Got: \(urlString)"
        )
    }

    func testDitoTokenRequest_JSONStructure_MatchesAndroid() {
        let tokenRequest = DitoTokenRequest(
            platformApiKey: "test_api_key",
            sha1Signature: "test_signature",
            token: "test_fcm_token"
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonData = try? encoder.encode(tokenRequest),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Failed to encode DitoTokenRequest to JSON")
            return
        }

        XCTAssertNotNil(jsonObject["platform_api_key"], "Must have platform_api_key")
        XCTAssertNotNil(jsonObject["sha1_signature"], "Must have sha1_signature")
        XCTAssertNotNil(jsonObject["token"], "Must have token")
        XCTAssertNotNil(jsonObject["platform"], "Must have platform")
        XCTAssertNotNil(jsonObject["id_type"], "Must have id_type")
        XCTAssertNotNil(jsonObject["encoding"], "Must have encoding field (Android compatibility)")

        XCTAssertEqual(jsonObject["platform"] as? String, "iOS", "Platform should be 'iOS' to match Android pattern")
        XCTAssertEqual(jsonObject["encoding"] as? String, "base64", "Encoding should be 'base64'")

        XCTAssertNil(jsonObject["ios_token_type"], "Must NOT have ios_token_type field (Android doesn't have this)")

        print("✅ DitoTokenRequest JSON structure (matches Android):\n\(jsonString)")
    }

    func testDitoEventRequest_EventIsObject_NotString() {
        let event = DitoEvent(
            action: "test_action",
            revenue: 99.99,
            createdAt: Date(),
            customData: ["key": "value"]
        )

        let eventRequest = DitoEventRequest(
            platformApiKey: "test_api_key",
            sha1Signature: "test_signature",
            event: event
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonData = try? encoder.encode(eventRequest),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Failed to encode DitoEventRequest to JSON")
            return
        }

        XCTAssertNotNil(jsonObject["event"], "Must have event field")

        let eventField = jsonObject["event"]
        XCTAssertTrue(
            eventField is [String: Any],
            "Event field must be an object (dictionary), not a string. This matches Android behavior."
        )

        if let eventObject = eventField as? [String: Any] {
            XCTAssertNotNil(eventObject["action"], "Event object must have action field")
            XCTAssertEqual(eventObject["action"] as? String, "test_action")
            XCTAssertNotNil(eventObject["revenue"], "Event object must have revenue field")
            XCTAssertNotNil(eventObject["created_at"], "Event object must have created_at field")
        }

        print("✅ DitoEventRequest JSON structure (event as object, matches Android):\n\(jsonString)")
    }

    func testDitoEventRequest_JSONStructure_MatchesAndroid() {
        let event = DitoEvent(
            action: "purchase",
            revenue: 150.00,
            customData: ["product_id": "123", "category": "electronics"]
        )

        let eventRequest = DitoEventRequest(
            platformApiKey: "test_api_key",
            sha1Signature: "test_signature",
            event: event
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonData = try? encoder.encode(eventRequest),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Failed to encode DitoEventRequest to JSON")
            return
        }

        XCTAssertNotNil(jsonObject["platform_api_key"])
        XCTAssertNotNil(jsonObject["sha1_signature"])
        XCTAssertNotNil(jsonObject["event"])
        XCTAssertNotNil(jsonObject["id_type"])
        XCTAssertNotNil(jsonObject["network_name"])
        XCTAssertNotNil(jsonObject["encoding"])

        XCTAssertEqual(jsonObject["id_type"] as? String, "id")
        XCTAssertEqual(jsonObject["network_name"] as? String, "pt")
        XCTAssertEqual(jsonObject["encoding"] as? String, "base64")
    }

    func testDitoDataNotification_HasCompleteStructure() {
        let data = DitoDataNotification(
            identifier: "123",
            reference: "ref_123",
            notification: "notif_123",
            notificationLogId: "log_123",
            userId: "user_123",
            deviceType: "iPhone",
            channel: "DITO",
            notificationName: "Test Notification",
            title: "Test Title",
            message: "Test Message",
            link: "app://deeplink",
            logId: "log_456"
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonData = try? encoder.encode(data),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Failed to encode DitoDataNotification to JSON")
            return
        }

        XCTAssertEqual(jsonObject.count, 12, "iOS DitoDataNotification should have 12 fields (complete structure)")

        XCTAssertNotNil(jsonObject["identifier"])
        XCTAssertNotNil(jsonObject["reference"])
        XCTAssertNotNil(jsonObject["notification"])
        XCTAssertNotNil(jsonObject["notification_log_id"])
        XCTAssertNotNil(jsonObject["user_id"])
        XCTAssertNotNil(jsonObject["device_type"])
        XCTAssertNotNil(jsonObject["channel"])
        XCTAssertNotNil(jsonObject["notification_name"])
        XCTAssertNotNil(jsonObject["title"])
        XCTAssertNotNil(jsonObject["message"])
        XCTAssertNotNil(jsonObject["link"])
        XCTAssertNotNil(jsonObject["log_id"])

        print("✅ DitoDataNotification JSON structure (complete, iOS is correct):\n\(jsonString)")
    }

    func testEndpointURLs_MatchAndroid() {
        let testCases: [(String, DitoRouterService, String)] = [
            (
                "Identify",
                .identify(network: "portal", id: "user123", data: DitoSignupRequest(platformApiKey: "key", sha1Signature: "sig", userData: nil)),
                "https://login.plataformasocial.com.br/users/portal/user123/signup"
            ),
            (
                "Track",
                .track(reference: "ref123", data: DitoEventRequest(platformApiKey: "key", sha1Signature: "sig", event: DitoEvent(action: "test"))),
                "https://events.plataformasocial.com.br/users/ref123"
            ),
            (
                "Register Token",
                .register(reference: "ref123", data: DitoTokenRequest(platformApiKey: "key", sha1Signature: "sig", token: "token")),
                "https://notification.plataformasocial.com.br/users/ref123/mobile-tokens/"
            ),
            (
                "Unregister Token",
                .unregister(reference: "ref123", data: DitoTokenRequest(platformApiKey: "key", sha1Signature: "sig", token: "token")),
                "https://notification.plataformasocial.com.br/users/ref123/mobile-tokens/disable/"
            ),
            (
                "Open Notification",
                .open(notificationId: "notif123", data: DitoNotificationOpenRequest(
                    platformApiKey: "key",
                    sha1Signature: "sig",
                    data: DitoDataNotification(
                        identifier: "123",
                        reference: "ref",
                        notification: "n",
                        notificationLogId: "l",
                        userId: "u",
                        deviceType: "d",
                        channel: "c",
                        notificationName: "nn",
                        title: "t",
                        message: "m",
                        link: "l",
                        logId: "li"
                    )
                )),
                "https://notification.plataformasocial.com.br/notifications/notif123/open/"
            )
        ]

        for (name, router, expectedURL) in testCases {
            guard let urlRequest = try? router.asURLRequest(),
                  let actualURL = urlRequest.url?.absoluteString else {
                XCTFail("Failed to create URL request for \(name)")
                continue
            }

            XCTAssertEqual(
                actualURL,
                expectedURL,
                "\(name) endpoint URL must match Android: expected \(expectedURL), got \(actualURL)"
            )
            print("✅ \(name): \(actualURL)")
        }
    }
}
