import XCTest
@testable import DitoSDK

final class HappyPathTests: XCTestCase {
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

    func testIdentifyReturns200() {
        Dito.identify(id: helper.userId, name: "Test User iOS")
        Thread.sleep(forTimeInterval: 5)
        let code = ProdURLProtocol.lastCode()
        XCTAssertTrue(code == 200 || code == 204, "identify deve retornar 200 ou 204, obtido: \(code)")
    }

    func testTrackReturns200() {
        Dito.identify(id: helper.userId, name: "Test User iOS")
        Thread.sleep(forTimeInterval: 5)
        ProdURLProtocol.reset()
        Dito.track(action: "test-event")
        Thread.sleep(forTimeInterval: 5)
        let code = ProdURLProtocol.lastCode()
        XCTAssertTrue(code == 200 || code == 204, "track deve retornar 200 ou 204, obtido: \(code)")
    }

    func testRegisterDeviceReturns200() {
        Dito.identify(id: helper.userId, name: "Test User iOS")
        Thread.sleep(forTimeInterval: 5)
        ProdURLProtocol.reset()
        Dito.registerDevice(token: "fake-apns-\(helper.userId)")
        Thread.sleep(forTimeInterval: 5)
        let code = ProdURLProtocol.lastCode()
        XCTAssertTrue(code == 200 || code == 204, "registerDevice deve retornar 200 ou 204, obtido: \(code)")
    }

    func testUnregisterDeviceReturns200() {
        Dito.identify(id: helper.userId, name: "Test User iOS")
        Thread.sleep(forTimeInterval: 5)
        Dito.registerDevice(token: "fake-apns-\(helper.userId)")
        Thread.sleep(forTimeInterval: 5)
        ProdURLProtocol.reset()
        Dito.unregisterDevice(token: "fake-apns-\(helper.userId)")
        Thread.sleep(forTimeInterval: 5)
        let code = ProdURLProtocol.lastCode()
        XCTAssertTrue(code == 200 || code == 204, "unregisterDevice deve retornar 200 ou 204, obtido: \(code)")
    }
}
