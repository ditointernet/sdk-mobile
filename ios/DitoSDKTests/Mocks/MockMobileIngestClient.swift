@testable import DitoSDK

final class MockMobileIngestClient: MobileIngestClientProtocol {
    var activityCallCount = 0
    var lastRequest: Mobileingest_V1_Request?
    var shouldThrow = false
    var errorToThrow: Error = MobileIngestError(message: "mock error")

    func activity(_ request: Mobileingest_V1_Request) async throws -> Mobileingest_V1_Response {
        activityCallCount += 1
        lastRequest = request
        if shouldThrow { throw errorToThrow }
        return Mobileingest_V1_Response()
    }
}
