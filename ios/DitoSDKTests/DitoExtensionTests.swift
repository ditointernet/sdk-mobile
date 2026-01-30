import XCTest
@testable import DitoSDK

class DitoExtensionTests: XCTestCase {

    func testSha1_ReturnsCorrectHash() {
        let string = "test@example.com"
        let hash = string.sha1

        XCTAssertFalse(hash.isEmpty, "Hash should not be empty")
        XCTAssertEqual(hash.count, 40, "SHA1 hash should be 40 characters")
    }

    func testSha1_Consistency() {
        let string = "test@example.com"
        let hash1 = string.sha1
        let hash2 = string.sha1

        XCTAssertEqual(hash1, hash2, "Same input should produce same hash")
    }

    func testValidateEmail_ValidEmail() {
        let validEmail = "test@example.com"
        let validated = validEmail.validateEmail

        XCTAssertNotNil(validated, "Valid email should not be nil")
        XCTAssertEqual(validated, validEmail, "Valid email should be returned")
    }

    func testValidateEmail_InvalidEmail() {
        let invalidEmail = "invalid email"
        let validated = invalidEmail.validateEmail

        XCTAssertNil(validated, "Invalid email should be nil")
    }

    func testValidateEmail_InvalidFormat() {
        let invalidEmail = "notanemail"
        let validated = invalidEmail.validateEmail

        XCTAssertNil(validated, "Invalid format email should be nil")
    }

    func testValidateEmail_WithoutAtSymbol() {
        let invalidEmail = "testexample.com"
        let validated = invalidEmail.validateEmail

        XCTAssertNil(validated, "Email without @ symbol should be nil")
    }

    func testValidateEmail_WithoutDomain() {
        let invalidEmail = "test@"
        let validated = invalidEmail.validateEmail

        XCTAssertNil(validated, "Email without domain should be nil")
    }

    func testValidateEmail_WithSpaces() {
        let invalidEmail = "test @example.com"
        let validated = invalidEmail.validateEmail

        XCTAssertNil(validated, "Email with spaces should be nil")
    }

    func testValidateEmail_EmptyString() {
        let emptyEmail = ""
        let validated = emptyEmail.validateEmail

        XCTAssertNil(validated, "Empty string should be nil")
    }

    func testValidateEmail_WithPlusSign() {
        let validEmail = "test+tag@example.com"
        let validated = validEmail.validateEmail

        XCTAssertNotNil(validated, "Email with + sign is valid")
        XCTAssertEqual(validated, validEmail)
    }

    func testValidateEmail_WithHyphen() {
        let validEmail = "test-name@example.com"
        let validated = validEmail.validateEmail

        XCTAssertNotNil(validated, "Email with hyphen is valid")
        XCTAssertEqual(validated, validEmail)
    }

    func testValidateEmail_WithDot() {
        let validEmail = "test.name@example.com"
        let validated = validEmail.validateEmail

        XCTAssertNotNil(validated, "Email with dot is valid")
        XCTAssertEqual(validated, validEmail)
    }

    func testValidateEmail_WithUnderscore() {
        let validEmail = "test_name@example.com"
        let validated = validEmail.validateEmail

        XCTAssertNotNil(validated, "Email with underscore is valid")
        XCTAssertEqual(validated, validEmail)
    }

    func testValidateEmail_WithMultipleDots() {
        let validEmail = "test.name.tag@example.co.uk"
        let validated = validEmail.validateEmail

        XCTAssertNotNil(validated, "Email with multiple dots is valid")
        XCTAssertEqual(validated, validEmail)
    }

    func testValidateEmail_WithNumbers() {
        let validEmail = "test123@example456.com"
        let validated = validEmail.validateEmail

        XCTAssertNotNil(validated, "Email with numbers is valid")
        XCTAssertEqual(validated, validEmail)
    }

    func testConvertToObject_WithValidJSON() {
        let jsonString = """
        {"name": "Test", "value": 123}
        """

        struct TestObject: Codable {
            let name: String
            let value: Int
        }

        let object = jsonString.convertToObject(type: TestObject.self)

        XCTAssertNotNil(object, "Object should be created from valid JSON")
        XCTAssertEqual(object?.name, "Test", "Name should match")
        XCTAssertEqual(object?.value, 123, "Value should match")
    }

    func testConvertToObject_WithInvalidJSON() {
        let invalidJSON = "not a json"

        struct TestObject: Codable {
            let name: String
        }

        let object = invalidJSON.convertToObject(type: TestObject.self)

        XCTAssertNil(object, "Object should be nil for invalid JSON")
    }

    func testFormatToDitoDate_FormatsCorrectly() {
        let date = Date(timeIntervalSince1970: 0)
        let formatted = date.formatToDitoDate

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let expected = dateFormatter.string(from: date)

        XCTAssertEqual(formatted, expected, "Date should be formatted correctly")
    }

    func testToString_ConvertsToJSONString() {
        struct TestStruct: Codable {
            let name: String
            let value: Int
        }

        let testObject = TestStruct(name: "Test", value: 123)
        let jsonString = testObject.toString

        XCTAssertNotNil(jsonString, "JSON string should not be nil")
        XCTAssertTrue(jsonString?.contains("Test") ?? false, "JSON should contain name")
        XCTAssertTrue(jsonString?.contains("123") ?? false, "JSON should contain value")
    }

    func testConvertToJson_WithValidData() {
        struct TestModel: Codable {
            let data: TestData
        }

        struct TestData: Codable {
            let name: String
        }

        let jsonData = """
        {"data": {"name": "Test"}}
        """.data(using: .utf8)!

        let result = jsonData.convertToJson(type: TestData.self)

        XCTAssertNotNil(result, "Result should not be nil")
        XCTAssertEqual(result?.name, "Test", "Name should match")
    }

    func testConvertToJson_WithInvalidData() {
        struct TestData: Codable {
            let name: String
        }

        let invalidData = "not json".data(using: .utf8)!
        let result = invalidData.convertToJson(type: TestData.self)

        XCTAssertNil(result, "Result should be nil for invalid data")
    }
}
