import XCTest
@testable import DitoSDK

final class ActivityMapperTests: XCTestCase {

    private var sut: ActivityMapper!

    override func setUp() {
        super.setUp()
        sut = ActivityMapper()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testMapFromDitoUser_withNilUserData_returnsIdentifyActivityWithEmptyFields() {
        // Arrange
        let userId = "test-user-id"

        // Act
        let activity = sut.mapFromDitoUser(userData: nil, userId: userId)

        // Assert
        XCTAssertEqual(activity.type, .activityIdentify)
        XCTAssertEqual(activity.identify.name, "")
        XCTAssertEqual(activity.identify.email, "")
        XCTAssertEqual(activity.identify.birthday, "")
        XCTAssertEqual(activity.identify.gender, "")
        XCTAssertTrue(activity.identify.customData.isEmpty)
        XCTAssertFalse(activity.id.isEmpty)
    }

    func testMapFromDitoUser_withFullUserData_mapsFieldsCorrectly() {
        // Arrange
        let userId = "test-user-id"
        let user = DitoUser(name: "John Doe", email: "john@example.com")

        // Act
        let activity = sut.mapFromDitoUser(userData: user, userId: userId)

        // Assert
        XCTAssertEqual(activity.type, .activityIdentify)
        XCTAssertEqual(activity.identify.name, "John Doe")
        XCTAssertEqual(activity.identify.email, "john@example.com")
        XCTAssertEqual(activity.identify.birthday, "")
        XCTAssertEqual(activity.identify.gender, "")
        XCTAssertTrue(activity.identify.customData.isEmpty)
    }

    func testCustomData_withStringValue_mapsToStringValue() {
        // Arrange
        let user = DitoUser(customData: ["key": "texto"])

        // Act
        let activity = sut.mapFromDitoUser(userData: user, userId: "uid")

        // Assert
        let cdValue = activity.identify.customData["key"]?.single
        if case .stringValue(let v)? = cdValue?.value {
            XCTAssertEqual(v, "texto")
        } else {
            XCTFail("Esperado stringValue para chave 'key'")
        }
    }

    func testCustomData_withDoubleValue_mapsToNumberValue() {
        // Arrange
        let user = DitoUser(customData: ["score": 3.14])

        // Act
        let activity = sut.mapFromDitoUser(userData: user, userId: "uid")

        // Assert
        let cdValue = activity.identify.customData["score"]?.single
        if case .numberValue(let v)? = cdValue?.value {
            XCTAssertEqual(v, 3.14, accuracy: 0.0001)
        } else {
            XCTFail("Esperado numberValue para chave 'score'")
        }
    }

    func testCustomData_withIntValue_mapsToNumberValue() {
        // Arrange
        let user = DitoUser(customData: ["pontos": 100])

        // Act
        let activity = sut.mapFromDitoUser(userData: user, userId: "uid")

        // Assert
        let cdValue = activity.identify.customData["pontos"]?.single
        if case .numberValue(let v)? = cdValue?.value {
            XCTAssertEqual(v, 100.0, accuracy: 0.0001)
        } else {
            XCTFail("Esperado numberValue para chave 'pontos'")
        }
    }

    func testCustomData_withBoolValue_mapsToBoostValue() {
        // Arrange
        let user = DitoUser(customData: ["ativo": true])

        // Act
        let activity = sut.mapFromDitoUser(userData: user, userId: "uid")

        // Assert
        let cdValue = activity.identify.customData["ativo"]?.single
        if case .boolValue(let v)? = cdValue?.value {
            XCTAssertTrue(v)
        } else {
            XCTFail("Esperado boolValue para chave 'ativo'")
        }
    }

    func testCustomData_withNullValue_mapsToNullValue() {
        // Arrange
        let user = DitoUser(customData: ["tag": NSNull()])

        // Act
        let activity = sut.mapFromDitoUser(userData: user, userId: "uid")

        // Assert
        let cdValue = activity.identify.customData["tag"]?.single
        if case .nullValue(_)? = cdValue?.value {
            // sucesso: null foi preservado
        } else {
            XCTFail("Esperado nullValue para chave 'tag'")
        }
    }

    func testCustomData_withMixedTypes_mapsAllCorrectly() {
        // Arrange
        let user = DitoUser(customData: ["nome": "Ana", "nota": 9.5, "ativo": true])

        // Act
        let activity = sut.mapFromDitoUser(userData: user, userId: "uid")
        let customData = activity.identify.customData

        // Assert
        if case .stringValue(let v)? = customData["nome"]?.single.value {
            XCTAssertEqual(v, "Ana")
        } else {
            XCTFail("Esperado stringValue para chave 'nome'")
        }
        if case .numberValue(let v)? = customData["nota"]?.single.value {
            XCTAssertEqual(v, 9.5, accuracy: 0.0001)
        } else {
            XCTFail("Esperado numberValue para chave 'nota'")
        }
        if case .boolValue(let v)? = customData["ativo"]?.single.value {
            XCTAssertTrue(v)
        } else {
            XCTFail("Esperado boolValue para chave 'ativo'")
        }
    }

    func testCustomData_withEmptyJson_returnsEmptyMap() {
        // Arrange
        let user = DitoUser(customData: [:] as [String: Any])

        // Act
        let activity = sut.mapFromDitoUser(userData: user, userId: "uid")

        // Assert
        XCTAssertTrue(activity.identify.customData.isEmpty)
    }

    func testCustomData_withInvalidJson_returnsEmptyMap() {
        // Arrange: decodifica DitoEvent com data contendo string não-JSON para exercitar customDataFromJson
        let rawJson = #"{"action": "test", "data": "nao-e-json"}"#.data(using: .utf8)!
        let event = try! JSONDecoder().decode(DitoEvent.self, from: rawJson)

        // Act
        let activity = sut.mapFromDitoEvent(event)

        // Assert
        XCTAssertTrue(activity.track.data.isEmpty)
    }

    func testBuildRequest_withValidInputs_populatesAllRequiredFields() {
        // Arrange
        let userId = "test-user-id"
        let activity = sut.mapFromDitoUser(userData: nil, userId: userId)

        // Act
        let request = sut.buildRequest(userId: userId, activities: [activity])

        // Assert
        XCTAssertEqual(request.userID, userId)
        XCTAssertEqual(request.activities.count, 1)
        XCTAssertFalse(request.device.deviceID.isEmpty)
        XCTAssertEqual(request.sdk.lang, "swift")
        XCTAssertEqual(request.app.platform, "iOS")
    }
}
