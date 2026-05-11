import Foundation

enum TestConfig {
    static var apiKey: String {
        guard let v = ProcessInfo.processInfo.environment["DITO_TEST_API_KEY"], !v.isEmpty
        else {
            preconditionFailure(
                "DITO_TEST_API_KEY é obrigatória no fluxo legado (quando DITO_TEST_API_SECRET, após trim, não está vazio)"
            )
        }
        return v
    }

    static var apiSecret: String {
        ProcessInfo.processInfo.environment["DITO_TEST_API_SECRET"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var xApiKey: String {
        (ProcessInfo.processInfo.environment["DITO_TEST_X_API_KEY"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let prodBaseURL = "https://ingest.dito.com.br/mobile"
}
