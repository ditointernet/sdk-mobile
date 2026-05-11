import XCTest
@testable import DitoSDK

final class NotificationTests: XCTestCase {
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

    func testNotificationClickReturns200() {
        let userInfo: [AnyHashable: Any] = [
            "notification": "test-notif-\(helper.userId)",
            "reference": "test-ref-\(helper.userId)",
            "user_id": helper.userId,
            "notification_name": "Integration Test Notification"
        ]
        Dito.identify(id: helper.userId, name: "Notif User iOS")
        Thread.sleep(forTimeInterval: 5)
        ProdURLProtocol.reset()
        Dito.notificationClick(userInfo: userInfo)
        Thread.sleep(forTimeInterval: 5)
        let code = ProdURLProtocol.lastCode()
        XCTAssertTrue(code == 200 || code == 204, "notificationClick deve retornar 200 ou 204, obtido: \(code)")
    }

    func testNotificationReceivedReturns200() {
        let userInfo: [AnyHashable: Any] = [
            "notification": "test-notif-\(helper.userId)",
            "reference": "test-ref-\(helper.userId)",
            "user_id": helper.userId,
            "notification_name": "Integration Test Notification"
        ]
        Dito.identify(id: helper.userId, name: "Notif User iOS")
        Thread.sleep(forTimeInterval: 5)
        ProdURLProtocol.reset()
        Dito.notificationReceived(userInfo: userInfo, token: "fake-apns-\(helper.userId)")
        Thread.sleep(forTimeInterval: 5)
        let code = ProdURLProtocol.lastCode()
        XCTAssertTrue(code == 200 || code == 204, "notificationReceived deve retornar 200 ou 204, obtido: \(code)")
    }
}
