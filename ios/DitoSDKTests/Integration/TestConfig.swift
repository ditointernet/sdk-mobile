import Foundation

enum TestConfig {
    static var apiKey: String {
        guard let v = ProcessInfo.processInfo.environment["DITO_TEST_API_KEY"], !v.isEmpty
        else { preconditionFailure("DITO_TEST_API_KEY não definida") }
        return v
    }

    static var apiSecret: String {
        guard let v = ProcessInfo.processInfo.environment["DITO_TEST_API_SECRET"], !v.isEmpty
        else { preconditionFailure("DITO_TEST_API_SECRET não definida") }
        return v
    }

    static let prodBaseURL = "https://ingest.dito.com.br/mobile"
}
