import Foundation
@testable import DitoSDK

class MockDitoNotificationService: DitoServiceManager {
    var registerCalled = false
    var registerReference: String?
    var registerData: DitoTokenRequest?
    var registerCompletion: ((DitoTokenModel?, Error?) -> Void)?

    var unregisterCalled = false
    var unregisterReference: String?
    var unregisterData: DitoTokenRequest?
    var unregisterCompletion: ((DitoTokenModel?, Error?) -> Void)?

    var readCalled = false
    var readNotificationId: String?
    var readData: DitoNotificationOpenRequest?
    var readCompletion: ((DitoIdentifyModel?, Error?) -> Void)?

    var shouldSucceed = true
    var mockError: Error?
    var mockTokenResponse: DitoTokenModel?
    var mockReadResponse: DitoIdentifyModel?

    override func register(
        reference: String,
        data: DitoTokenRequest,
        completion: @escaping (_ success: DitoTokenModel?, _ error: Error?) -> Void
    ) {
        registerCalled = true
        registerReference = reference
        registerData = data
        registerCompletion = completion

        if shouldSucceed {
            completion(mockTokenResponse, nil)
        } else {
            completion(nil, mockError ?? NSError(domain: "MockError", code: 500))
        }
    }

    override func unregister(
        reference: String,
        data: DitoTokenRequest,
        completion: @escaping (_ success: DitoTokenModel?, _ error: Error?) -> Void
    ) {
        unregisterCalled = true
        unregisterReference = reference
        unregisterData = data
        unregisterCompletion = completion

        if shouldSucceed {
            completion(mockTokenResponse, nil)
        } else {
            completion(nil, mockError ?? NSError(domain: "MockError", code: 500))
        }
    }

    override func read(
        notificationId: String,
        data: DitoNotificationOpenRequest,
        completion: @escaping (_ success: DitoIdentifyModel?, _ error: Error?) -> Void
    ) {
        readCalled = true
        readNotificationId = notificationId
        readData = data
        readCompletion = completion

        if shouldSucceed {
            completion(mockReadResponse, nil)
        } else {
            completion(nil, mockError ?? NSError(domain: "MockError", code: 500))
        }
    }
}
