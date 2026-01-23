internal import CoreData
import CryptoKit
import XCTest

@testable import DitoSDK

class DitoSDKTests: XCTestCase {
    var sut: DitoNotificationReadDataManager!
    let timeout = TimeInterval(20)

    override func setUp() {
        super.setUp()
        sut = DitoNotificationReadDataManager()
        DitoIdentifyDataManager.shared.deleteIdentifyStamp()
        DitoIdentifyDataManager.shared.identitySaveCallback = nil
    }

    override func tearDown() {
        DitoIdentifyDataManager.shared.deleteIdentifyStamp()
        DitoIdentifyDataManager.shared.identitySaveCallback = nil
        super.tearDown()
    }

    // MARK: - Track without identify tests
    /// Should save event to CoreData when tracking without prior identify
    func testTrackEventWithoutIdentify_SavesToCoreData() {
        let trackDataManager = DitoTrackDataManager()
        let action = "botao_track_pressionado"

        let event = DitoEvent(
            action: action,
            customData: nil
        )

        // Track without identify first
        Dito.track(event: event)

        // Give it time to save
        let expectation = XCTestExpectation(
            description: "Event saved to CoreData"
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: self.timeout)

        // Verify event was saved in CoreData
        let savedTracks = trackDataManager.fetchAll
        XCTAssertGreaterThan(
            savedTracks.count,
            0,
            "Event should be saved to CoreData"
        )
    }

    /// Should save token to CoreData when registering without prior identify
    func testRegisterTokenWithoutIdentify_SavesToCoreData() {
        let notificationRegisterDataManager =
            DitoNotificationRegisterDataManager()
        let token = "test_fcm_token_123"

        // Register token without identify first
        Dito.registerDevice(token: token)

        // Give it time to save
        let expectation = XCTestExpectation(
            description: "Token saved to CoreData"
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: self.timeout)

        // Verify token was saved in CoreData
        let savedNotifications = notificationRegisterDataManager.fetch
        XCTAssertNotNil(savedNotifications, "Token should be saved to CoreData")
    }

    /// Should save token unregister to CoreData when unregistering without prior identify
    func testUnregisterTokenWithoutIdentify_SavesToCoreData() {
        let notificationUnregisterDataManager =
            DitoNotificationUnregisterDataManager()
        let token = "test_fcm_token_456"

        // First register the token
        Dito.registerDevice(token: token)

        // Give it time to save
        let expectation1 = XCTestExpectation(description: "Token registered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: self.timeout)

        // Now unregister without identify
        Dito.unregisterDevice(token: token)

        // Give it time to save
        let expectation2 = XCTestExpectation(
            description: "Token unregister saved to CoreData"
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: self.timeout)

        // Verify unregister was saved in CoreData
        let savedNotifications = notificationUnregisterDataManager.fetch
        XCTAssertNotNil(
            savedNotifications,
            "Token unregister should be saved to CoreData"
        )
    }

    // MARK: - Track with identify tests

    /// Should make API request when tracking after identify
    func testTrackEventWithIdentify_MakesAPIRequest() {
        let expectIdentify = expectation(description: "identify request completed")
        let expectTrack = expectation(description: "track request completed")

        let id = "a24696993af35a5190a0f7f41a7e508b"
        let user = DitoUser(
            name: "Test iOS",
            gender: .masculino,
            email: "teste-ios@dito.com.br",
            birthday: Date(),
            location: "São Paulo",
            createdAt: nil,
            customData: nil
        )

        // Step 1: Perform identify and wait for it to complete
        var identifyCallbackExecuted = false
        DitoIdentifyDataManager.shared.identitySaveCallback = {
            if !identifyCallbackExecuted {
                identifyCallbackExecuted = true
                expectIdentify.fulfill()
            }
        }

        Dito.identify(id: id, data: user)
        wait(for: [expectIdentify], timeout: self.timeout)

        // Step 2: After identify is complete, track the event
        let event = DitoEvent(
            action: "evento de teste"
        )
        Dito.track(event: event)

        // Step 3: Wait a moment for track to be saved to CoreData
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectTrack.fulfill()
        }
        wait(for: [expectTrack], timeout: self.timeout)

        // Verify both operations were successful
        XCTAssertNotNil(user.email, "User email should not be nil after identify")

        let identifyDataManager = DitoIdentifyDataManager()
        let savedIdentify = identifyDataManager.fetch
        XCTAssertNotNil(savedIdentify, "Identify should be saved in CoreData")

        let trackDataManager = DitoTrackDataManager()
        let savedTracks = trackDataManager.fetchAll
        XCTAssertGreaterThan(savedTracks.count, 0, "Track event should be saved in CoreData")

        // Clean up
        DitoIdentifyDataManager.shared.identitySaveCallback = nil
    }

    /// Should make API request when registering token after identify
    func testRegisterTokenWithIdentify_MakesAPIRequest() {
        let expect = expectation(description: "register token with identify")

        let token = "fcm_token_with_identify_123"

        // First identify the user
        let id = "user_token_123"
        let user = DitoUser(
            name: "Maria Santos",
            gender: .feminino,
            email: "maria@teste.com.br",
            birthday: Date(),
            location: "Rio de Janeiro",
            createdAt: nil,
            customData: nil
        )

        // Set completion closure using the shared singleton
        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expect.fulfill()
        }

        Dito.identify(id: id, data: user)
        Dito.registerDevice(token: token)
        wait(for: [expect], timeout: self.timeout)

        XCTAssertNotNil(user.email)
    }

    /// Should make API request when unregistering token after identify
    func testUnregisterTokenWithIdentify_MakesAPIRequest() {
        let expect = expectation(description: "unregister token with identify")

        let token = "fcm_token_unregister_123"

        // First identify the user
        let id = "user_unregister_123"
        let user = DitoUser(
            name: "Pedro Costa",
            gender: .masculino,
            email: "pedro@teste.com.br",
            birthday: Date(),
            location: "Belo Horizonte",
            createdAt: nil,
            customData: nil
        )

        // Set completion closure using the shared singleton
        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expect.fulfill()
        }

        Dito.identify(id: id, data: user)
        Dito.unregisterDevice(token: token)
        wait(for: [expect], timeout: self.timeout)

        XCTAssertNotNil(user.email)
    }

    func testHashCompatibility() {
        let string = "xcaoI1lXnyraH1MCQtRPkbUOAqAS6ywikNGQTiZw"

        XCTAssertEqual(cryptoSHA1Hash(string), sha1Hash(string))
    }

    func testCreateAt() {
        let expect = expectation(
            description: "register an user with an valid created at date"
        )

        let id = "1020"

        let createdAt = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let user = DitoUser(
            name: nil,
            gender: nil,
            email: nil,
            birthday: nil,
            location: nil,
            createdAt: createdAt,
            customData: nil
        )

        // Set completion closure using the shared singleton
        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expect.fulfill()
        }

        Dito.identify(id: id, data: user)
        wait(for: [expect], timeout: self.timeout)

        XCTAssertEqual(user.createdAt, dateFormatter.string(from: createdAt))
    }

    func testInvalidEmail() {
        let expect = expectation(
            description: "register an user with an invalid email"
        )

        let id = "1020"
        let email = "a bc@test.com"

        let user = DitoUser(
            name: nil,
            gender: nil,
            email: email,
            birthday: nil,
            location: nil,
            createdAt: nil,
            customData: nil
        )

        // Set completion closure using the shared singleton
        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expect.fulfill()
        }

        Dito.identify(id: id, data: user)

        wait(for: [expect], timeout: self.timeout)

        XCTAssertNil(user.email)
    }

    func testValidEmail() {
        let expect = expectation(
            description: "register an user with a valid email"
        )

        let id = "1020"

        let email = "a_bc@test.com"

        let user = DitoUser(
            name: nil,
            gender: nil,
            email: email,
            birthday: nil,
            location: nil,
            createdAt: nil,
            customData: nil
        )

        // Set completion closure using the shared singleton
        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expect.fulfill()
        }

        Dito.identify(id: id, data: user)

        wait(for: [expect], timeout: self.timeout)

        XCTAssertEqual(user.email, email)
    }

    func testValidDate() {
        let expect = expectation(
            description: "register an user with an valid birthdate"
        )

        let id = "1020"

        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let user = DitoUser(
            name: nil,
            gender: nil,
            email: nil,
            birthday: date,
            location: nil,
            createdAt: nil,
            customData: nil
        )

        // Set completion closure using the shared singleton
        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expect.fulfill()
        }

        Dito.identify(id: id, data: user)

        wait(for: [expect], timeout: self.timeout)

        XCTAssertEqual(user.birthday, dateFormatter.string(from: date))
    }

    func testIdentify() {
        let expect = expectation(description: "register an user")

        let id = "1020"

        let user = DitoUser(
            name: "Brenno de Moura",
            gender: .masculino,
            email: "teste@teste.com",
            birthday: Date(),
            location: "Goiânia",
            createdAt: Date(),
            customData: nil
        )

        // Set completion closure using the shared singleton
        DitoIdentifyDataManager.shared.identitySaveCallback = {
            expect.fulfill()
        }

        Dito.identify(id: id, data: user)

        wait(for: [expect], timeout: self.timeout)

        XCTAssertNotNil(user.email)
    }

    //MARK: Identify

    func testPersistenceSaveIdentify() {

        let dataManager = DitoIdentifyDataManager()
        let result = dataManager.save(
            id: "sdk223",
            reference: "drrt",
            json: "rtrt:{{rtrt:}}",
            send: true
        )

        XCTAssertTrue(
            result,
            "Result must be true when nothing idetify has been saved"
        )
    }

    func testPersistenceFetchIdentify() {

        let dataManager = DitoIdentifyDataManager()
        let result = dataManager.fetch

        XCTAssertNotNil(result, "Result must be not nil")
    }

    func testPersistenceDeleteIdentify() {

        let dataManager = DitoIdentifyDataManager()
        let result = dataManager.delete(id: "1021")

        XCTAssertTrue(result, "Result must be true")
    }

    //MARK: Track

    func testPersistenceSaveTrack() {

        let dataManager = DitoTrackDataManager()
        let result = dataManager.save(
            event: "toque-no-botao-de-cancelar",
            retry: 1
        )

        XCTAssertTrue(result, "Result must be true")
    }

    func testPersistenceFetchTrack() {

        let dataManager = DitoTrackDataManager()
        let result = dataManager.fetchAll

        XCTAssertTrue(!result.isEmpty, "Result must not be empty - tracks should exist")
    }

    func testPersistenceDeleteTrack() {

        let dataManager = DitoTrackDataManager()

        // First save a track to ensure we have data to delete
        let saveResult = dataManager.save(
            event: "toque-no-botao-de-cancelar",
            retry: 1
        )
        XCTAssertTrue(saveResult, "Track should be saved before deleting")

        let tracks = dataManager.fetchAll
        var result: Bool = false

        if !tracks.isEmpty, let id = tracks.first?.objectID {
            result = dataManager.delete(with: id)
        }

        XCTAssertTrue(result, "Result must be true")
    }

    //MARK: Notify

    func testPersistenceSaveNotify() {
        let JSON = "{\"title\": \"New Notification\"}"
        let saveResult = sut.save(with: JSON)
        XCTAssertTrue(saveResult, "Result must be true")
    }

    func testPersistenceFetchNotify() {
        let JSON = "{\"title\": \"New Notification\"}"
        _ = sut.save(with: JSON)
        _ = sut.save(with: JSON)
        _ = sut.save(with: JSON)
        _ = sut.save(with: JSON)
        _ = sut.save(with: JSON)

        let result = sut.fetchAll

        XCTAssertNotNil(result, "Result must be not nil")
    }

    func testPersistenceDeleteNotify() {

        // First save a notification to ensure we have data to delete
        let JSON = "{\"title\": \"New Notification\"}"
        let saveResult = sut.save(with: JSON)
        XCTAssertTrue(saveResult, "Notification should be saved before deleting")

        let notifications = sut.fetchAll
        var result: Bool = false

        if !notifications.isEmpty, let id = notifications.first?.objectID {
            result = sut.delete(with: id)
        }
        XCTAssertTrue(result, "Result must be true")
    }
}

@available(iOS 16, *)
extension DitoSDKTests {

    func cryptoSHA1Hash(_ string: String) -> String {
        Insecure.SHA1.hash(data: string.data(using: .utf8) ?? Data())
            .map {
                String(format: "%02hhx", $0)
            }.joined()
    }

    func sha1Hash(_ string: String) -> String {
        SHA1.hexString(from: string)?
            .lowercased()
            .replacingOccurrences(of: " ", with: "") ?? ""
    }
}
