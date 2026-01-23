import Foundation
@testable import DitoSDK

class MockDitoTrackService: DitoServiceManager {
    var eventCalled = false
    var eventReference: String?
    var eventData: DitoEventRequest?
    var eventCompletion: (([DitoTrackModel]?, Error?) -> Void)?

    var shouldSucceed = true
    var mockError: Error?
    var mockResponse: [DitoTrackModel]?

    override func event(
        reference: String,
        data: DitoEventRequest,
        completion: @escaping (_ success: [DitoTrackModel]?, _ error: Error?) -> Void
    ) {
        eventCalled = true
        eventReference = reference
        eventData = data
        eventCompletion = completion

        if shouldSucceed {
            completion(mockResponse, nil)
        } else {
            completion(nil, mockError ?? NSError(domain: "MockError", code: 500))
        }
    }
}
