import Connect
import Foundation

protocol MobileIngestClientProtocol: Sendable {
    func activity(_ request: Mobileingest_V1_Request) async throws -> Mobileingest_V1_Response
}

final class MobileIngestClient: MobileIngestClientProtocol {
    private let generatedClient: Mobileingest_V1_MobileIngestServiceClientInterface
    private let authHeaders: Connect.Headers

    private static let ingestBaseURL = "https://ingest.dito.com.br/mobile"

    init(authHeaders: [String: String], urlSessionConfiguration: URLSessionConfiguration? = nil) {
        self.authHeaders = authHeaders.mapValues { [$0] }
        let protocolClient = ProtocolClient(
            httpClient: URLSessionHTTPClient(configuration: urlSessionConfiguration ?? .default),
            config: ProtocolClientConfig(
                host: MobileIngestClient.ingestBaseURL,
                networkProtocol: .connect,
                codec: ProtoCodec()
            )
        )
        generatedClient = Mobileingest_V1_MobileIngestServiceClient(client: protocolClient)
    }

    func activity(_ request: Mobileingest_V1_Request) async throws -> Mobileingest_V1_Response {
        let response = await generatedClient.activity(request: request, headers: authHeaders)
        guard let message = response.message else {
            throw MobileIngestError(message: response.error?.message ?? "unknown error")
        }
        return message
    }

    static func withLegacyAuth(
        apiKey: String,
        sha1Signature: String,
        urlSessionConfiguration: URLSessionConfiguration? = nil
    ) -> MobileIngestClient {
        MobileIngestClient(
            authHeaders: [
                "platform_api_key": apiKey,
                "sha1_signature": sha1Signature,
            ],
            urlSessionConfiguration: urlSessionConfiguration
        )
    }

    static func withApiKey(
        _ apiKey: String,
        bundleId: String,
        urlSessionConfiguration: URLSessionConfiguration? = nil
    ) -> MobileIngestClient {
        MobileIngestClient(
            authHeaders: [
                "X-Api-Key": apiKey,
                "Bundle-Id": bundleId,
            ],
            urlSessionConfiguration: urlSessionConfiguration
        )
    }

    static func buildFromDitoConfig() -> MobileIngestClient {
        #if DEBUG
        let urlSessionConfiguration = Dito.testURLSessionConfiguration
        #else
        let urlSessionConfiguration: URLSessionConfiguration? = nil
        #endif
        return Dito.apiKey.isEmpty
            ? withLegacyAuth(apiKey: Dito.appKey, sha1Signature: Dito.signature, urlSessionConfiguration: urlSessionConfiguration)
            : withApiKey(Dito.apiKey, bundleId: Dito.bundleId, urlSessionConfiguration: urlSessionConfiguration)
    }
}

struct MobileIngestError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
