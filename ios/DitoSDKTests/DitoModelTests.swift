import XCTest
@testable import DitoSDK

class DitoModelTests: XCTestCase {

    func testDitoUser_EncodesCorrectly() {
        let user = DitoUser(
            name: "Test User",
            gender: .masculino,
            email: "test@example.com",
            birthday: Date(),
            location: "São Paulo",
            createdAt: Date(),
            customData: ["key": "value"]
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        do {
            let data = try encoder.encode(user)
            XCTAssertFalse(data.isEmpty, "Encoded data should not be empty")

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decodedUser = try decoder.decode(DitoUser.self, from: data)

            XCTAssertEqual(decodedUser.name, user.name, "Name should match")
            XCTAssertEqual(decodedUser.email, user.email, "Email should match")
        } catch {
            XCTFail("Encoding/Decoding should not fail: \(error)")
        }
    }

    func testDitoUser_ValidatesEmail() {
        let validEmail = "test@example.com"
        let user = DitoUser(email: validEmail)

        XCTAssertEqual(user.email, validEmail, "Valid email should be preserved")
    }

    func testDitoUser_InvalidatesEmail() {
        let invalidEmail = "invalid email"
        let user = DitoUser(email: invalidEmail)

        XCTAssertNil(user.email, "Invalid email should be nil")
    }

    func testDitoUser_FormatsBirthday() {
        let date = Date(timeIntervalSince1970: 0)
        let user = DitoUser(birthday: date)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let expectedDateString = dateFormatter.string(from: date)

        XCTAssertEqual(user.birthday, expectedDateString, "Birthday should be formatted correctly")
    }

    func testDitoUser_FormatsCreatedAt() {
        let date = Date(timeIntervalSince1970: 0)
        let user = DitoUser(createdAt: date)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let expectedDateString = dateFormatter.string(from: date)

        XCTAssertEqual(user.createdAt, expectedDateString, "CreatedAt should be formatted correctly")
    }

    func testDitoUser_WithCustomData() {
        let customData: [String: Any] = [
            "premium": true,
            "points": 1000,
            "level": "gold"
        ]

        let user = DitoUser(customData: customData)

        XCTAssertNotNil(user.data, "Custom data should be converted to string")
    }

    func testDitoEvent_EncodesCorrectly() {
        let event = DitoEvent(
            action: "test_action",
            revenue: 99.99,
            createdAt: Date(),
            customData: ["key": "value"]
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        do {
            let data = try encoder.encode(event)
            XCTAssertFalse(data.isEmpty, "Encoded data should not be empty")

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decodedEvent = try decoder.decode(DitoEvent.self, from: data)

            XCTAssertEqual(decodedEvent.action, event.action, "Action should match")
            XCTAssertEqual(decodedEvent.revenue, event.revenue, "Revenue should match")
        } catch {
            XCTFail("Encoding/Decoding should not fail: \(error)")
        }
    }

    func testDitoEvent_WithCustomData() {
        let customData: [String: Any] = [
            "product_id": "123",
            "category": "electronics"
        ]

        let event = DitoEvent(action: "purchase", customData: customData)

        XCTAssertNotNil(event.data, "Custom data should be converted to string")
    }

    func testDitoEvent_WithoutCustomData() {
        let event = DitoEvent(action: "view", customData: nil)

        XCTAssertNil(event.data, "Data should be nil when customData is nil")
    }

    func testDitoNotificationReceived_ExtractsUserInfo() {
        let userInfo: [AnyHashable: Any] = [
            "notification": "notif_123",
            "user_id": "user_123",
            "link": "app://deeplink",
            "reference": "ref_123",
            "log_id": "log_123",
            "device_type": "iPhone",
            "channel": "DITO",
            "notification_name": "Test Notification",
            "title": "Test Title",
            "message": "Test Message"
        ]

        let notificationReceived = DitoNotificationReceived(with: userInfo)

        XCTAssertEqual(notificationReceived.notification, "notif_123", "Notification ID should match")
        XCTAssertEqual(notificationReceived.identifier, "user_123", "Identifier should match")
        XCTAssertEqual(notificationReceived.userId, "user_123", "User ID should match")
        XCTAssertEqual(notificationReceived.deeplink, "app://deeplink", "Deeplink should match")
        XCTAssertEqual(notificationReceived.reference, "ref_123", "Reference should match")
        XCTAssertEqual(notificationReceived.logId, "log_123", "Log ID should match")
        XCTAssertEqual(notificationReceived.deviceType, "iPhone", "Device type should match")
        XCTAssertEqual(notificationReceived.channel, "DITO", "Channel should match")
        XCTAssertEqual(notificationReceived.notificationName, "Test Notification", "Notification name should match")
        XCTAssertEqual(notificationReceived.title, "Test Title", "Title should match")
        XCTAssertEqual(notificationReceived.message, "Test Message", "Message should match")
    }

    func testDitoNotificationReceived_WithValidData() {
        let userInfo: [AnyHashable: Any] = [
            "notification": "notif_123",
            "user_id": "user_123",
            "link": "app://deeplink"
        ]

        let notificationReceived = DitoNotificationReceived(with: userInfo)

        XCTAssertFalse(notificationReceived.notification.isEmpty, "Notification should not be empty")
        XCTAssertFalse(notificationReceived.identifier.isEmpty, "Identifier should not be empty")
    }

    func testDitoNotificationReceived_WithInvalidData() {
        let userInfo: [AnyHashable: Any] = [:]

        let notificationReceived = DitoNotificationReceived(with: userInfo)

        XCTAssertTrue(notificationReceived.notification.isEmpty, "Notification should be empty")
        XCTAssertTrue(notificationReceived.identifier.isEmpty, "Identifier should be empty")
        XCTAssertTrue(notificationReceived.deeplink.isEmpty, "Deeplink should be empty")
    }
}
