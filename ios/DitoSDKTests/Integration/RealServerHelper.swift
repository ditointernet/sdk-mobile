import Foundation
@testable import DitoSDK

final class RealServerHelper {
    private(set) var userId: String = ""

    func setup() {
        Dito.configure(appKey: TestConfig.apiKey, appSecret: TestConfig.apiSecret)
        Thread.sleep(forTimeInterval: 0.5)
        userId = "test-ios-\(UUID().uuidString)"
    }
}
