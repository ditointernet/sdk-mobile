import Foundation
@testable import DitoSDK

final class MockMobileIngestClient: MobileIngestClientProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _activityCallCount = 0
    private var _activityRequests: [Mobileingest_V1_Request] = []
    private var _shouldSucceed = true
    private var _error: Error?

    var activityCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _activityCallCount
    }

    var lastActivityRequest: Mobileingest_V1_Request? {
        lock.lock()
        defer { lock.unlock() }
        return _activityRequests.last
    }

    var allActivityRequests: [Mobileingest_V1_Request] {
        lock.lock()
        defer { lock.unlock() }
        return _activityRequests
    }

    var shouldSucceed: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _shouldSucceed
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _shouldSucceed = newValue
        }
    }

    var errorToThrow: Error? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _error
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _error = newValue
        }
    }

    init() {}

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        _activityCallCount = 0
        _activityRequests.removeAll()
        _shouldSucceed = true
        _error = nil
    }

    func activity(_ request: Mobileingest_V1_Request) async throws -> Mobileingest_V1_Response {
        lock.lock()
        _activityCallCount += 1
        _activityRequests.append(request)
        let succeed = _shouldSucceed
        let err = _error
        lock.unlock()

        if !succeed {
            throw err ?? MobileIngestError(message: "mock failure")
        }
        return Mobileingest_V1_Response()
    }
}
