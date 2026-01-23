import Foundation
@testable import DitoSDK

class MockDitoIdentifyService: DitoServiceManager {
    var signupCalled = false
    var signupNetwork: String?
    var signupId: String?
    var signupData: DitoSignupRequest?
    var signupCompletion: ((DitoIdentifyModel?, Error?) -> Void)?

    var shouldSucceed = true
    var mockError: Error?
    var mockResponse: DitoIdentifyModel?

    override func signup(
        network: String,
        id: String,
        data: DitoSignupRequest,
        completion: @escaping (_ success: DitoIdentifyModel?, _ error: Error?) -> Void
    ) {
        signupCalled = true
        signupNetwork = network
        signupId = id
        signupData = data
        signupCompletion = completion

        if shouldSucceed {
            completion(mockResponse, nil)
        } else {
            completion(nil, mockError ?? NSError(domain: "MockError", code: 500))
        }
    }
}
