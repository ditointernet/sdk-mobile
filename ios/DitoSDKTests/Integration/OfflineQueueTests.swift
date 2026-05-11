import XCTest
@testable import DitoSDK

final class OfflineQueueTests: XCTestCase {
    var helper = RealServerHelper()

    override class func setUp() {
        URLProtocol.registerClass(ProdURLProtocol.self)
    }

    override class func tearDown() {
        URLProtocol.unregisterClass(ProdURLProtocol.self)
    }

    override func setUp() {
        super.setUp()
        helper.setup()
        ProdURLProtocol.reset()
    }

    func testTracksQueuedBeforeIdentifyAreFlushedAfterIdentify() {
        Dito.track(action: "offline-event-1")
        Dito.track(action: "offline-event-2")
        Dito.track(action: "offline-event-3")
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(ProdURLProtocol.allCodes().isEmpty, "nenhum HTTP deve ser enviado antes do identify")
        Dito.identify(id: helper.userId, name: "Offline iOS User")
        Thread.sleep(forTimeInterval: 15)
        Dito.track(action: "post-identify-probe")
        Thread.sleep(forTimeInterval: 5)
        let successCount = ProdURLProtocol.allCodes().filter { $0 == 200 || $0 == 204 }.count
        XCTAssertTrue(successCount >= 2, "deve haver pelo menos 2 respostas 200/204 após identify (identify + probe), obtido: \(ProdURLProtocol.allCodes())")
    }

    func testNotificationClickQueuedBeforeIdentifyIsFlushedAfterIdentify() {
        let userInfo: [AnyHashable: Any] = [
            "notification": "test-notif-offline-\(helper.userId)",
            "reference": "test-ref-offline-\(helper.userId)",
            "user_id": helper.userId,
            "notification_name": "Offline Test Notification"
        ]
        ProdURLProtocol.reset()
        Dito.notificationClick(userInfo: userInfo)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(ProdURLProtocol.allCodes().isEmpty, "nenhum HTTP deve ser enviado antes do identify")
        Dito.identify(id: helper.userId, name: "Offline Notif User")
        Thread.sleep(forTimeInterval: 15)
        Dito.track(action: "post-identify-probe")
        Thread.sleep(forTimeInterval: 5)
        let successCount = ProdURLProtocol.allCodes().filter { $0 == 200 || $0 == 204 }.count
        XCTAssertTrue(successCount >= 2, "deve haver pelo menos 2 respostas 200/204 após identify, obtido: \(ProdURLProtocol.allCodes())")
    }
}
