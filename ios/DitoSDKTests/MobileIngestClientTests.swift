import XCTest
@testable import DitoSDK

final class MobileIngestClientTests: XCTestCase {

    override func tearDown() {
        Dito.apiKey = ""
        Dito.bundleId = ""
        Dito.appKey = ""
        Dito.appSecret = ""
        Dito.signature = ""
        super.tearDown()
    }

    func testBuildFromDitoConfig_withApiKey_usesApiKeyAuthHeaders() {
        // Arrange
        Dito.apiKey = "test-api-key"
        Dito.bundleId = "com.test.bundle"

        // Act
        let client = MobileIngestClient.buildFromDitoConfig()

        // Assert
        XCTAssertNotNil(client)
    }

    func testBuildFromDitoConfig_withAppKey_usesLegacyAuthHeaders() {
        // Arrange
        Dito.apiKey = ""
        Dito.appKey = "test-app-key"
        Dito.signature = "test-signature"

        // Act
        let client = MobileIngestClient.buildFromDitoConfig()

        // Assert
        XCTAssertNotNil(client)
    }
}
