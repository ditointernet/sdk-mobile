import Foundation
import XCTest
@testable import DitoSDK

final class RealServerHelper {
    private(set) var userId: String = ""

    func setup() {
        Dito.testURLSessionConfiguration = ProdURLProtocol.makeConfiguration()
        Dito.testBadgeUpdater = { _ in }
        let secret = TestConfig.apiSecret
        if !secret.isEmpty {
            Dito.configure(appKey: TestConfig.apiKey, appSecret: secret)
        } else {
            let xKey = TestConfig.xApiKey
            guard !xKey.isEmpty else {
                XCTFail(
                    "DITO_TEST_X_API_KEY é obrigatória no modo solo (quando DITO_TEST_API_SECRET está vazio ou ausente). " +
                        "Não use DITO_TEST_API_KEY com Dito.configure(apiKey:bundleId:)."
                )
                return
            }
            guard let bundleId = Bundle(for: RealServerHelper.self).bundleIdentifier else {
                XCTFail("bundleIdentifier do bundle de testes é nil; necessário para Dito.configure(apiKey:bundleId:)")
                return
            }
            Dito.configure(apiKey: xKey, bundleId: bundleId)
        }
        TestHelpers.sleep(0.5)
        userId = "test-ios-\(UUID().uuidString)"
    }

    func teardown() {
        TestHelpers.resetAllState()
        Dito.testURLSessionConfiguration = nil
        Dito.testBadgeUpdater = nil
        ProdURLProtocol.reset()
    }
}
