import CoreData
import XCTest
@testable import DitoSDK

final class OfflineBatchAndNotificationsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestHelpers.resetAllState()
        Dito.appKey = "unit-test-app-key"
        Dito.appSecret = ""
        Dito.signature = "unit-test-signature"
        Dito.apiKey = ""
        Dito.bundleId = "br.com.dito.sdk.unit.tests"
    }

    override func tearDown() {
        TestHelpers.resetAllState()
        Dito.appKey = ""
        Dito.appSecret = ""
        Dito.signature = ""
        Dito.apiKey = ""
        Dito.bundleId = ""
        super.tearDown()
    }

    private func waitForActivityCalls(_ mock: MockMobileIngestClient, count: Int, timeout: TimeInterval = 10) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if mock.activityCallCount >= count { return }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("timed out waiting for \(count) ingest call(s); got \(mock.activityCallCount)")
    }

    private func waitForTrackPersistedCount(_ count: Int, timeout: TimeInterval = 10) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if DitoTrackDataManager().fetchOfflinePersistedTracks().count >= count { return }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("timed out waiting for \(count) track row(s); got \(DitoTrackDataManager().fetchOfflinePersistedTracks().count)")
    }

    private func waitForTrackRowsWithEvents(_ count: Int, timeout: TimeInterval = 10) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let rows = DitoTrackDataManager().fetchOfflinePersistedTracks()
            if rows.count >= count,
               rows.allSatisfy({ row in
                   guard let e = row.event, !e.isEmpty else { return false }
                   return true
               }) {
                return
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        let rows = DitoTrackDataManager().fetchOfflinePersistedTracks()
        XCTFail("timed out waiting for \(count) track rows with non-empty event; count=\(rows.count) eventsNil=\(rows.map { $0.event == nil })")
    }

    private func trackAndWait(_ sut: DitoTrack, action: String) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sut.track(data: DitoEvent(action: action, customData: nil)) { _ in cont.resume() }
        }
    }

    private func makeTokenRequest(token: String) -> DitoTokenRequest {
        DitoTokenRequest(platformAppKey: Dito.appKey, sha1Signature: Dito.signature, token: token)
    }

    private func makeEventRequest(action: String) -> DitoEventRequest {
        DitoEventRequest(
            platformAppKey: Dito.appKey,
            sha1Signature: Dito.signature,
            event: DitoEvent(action: action, customData: nil)
        )
    }

    #if DEBUG
    func testTrackWithoutIdentify_sendsAnonymouslyAndDoesNotPersist() async throws {
        DeviceIdProvider.setForTests("device-track-anon-1")
        let mock = MockMobileIngestClient()

        await trackAndWait(DitoTrack(client: mock), action: "anon_no_identify_alpha")

        XCTAssertEqual(mock.activityCallCount, 1)
        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, "")
        XCTAssertEqual(req.device.deviceID, "device-track-anon-1")
        let activity = try XCTUnwrap(req.activities.last)
        switch activity.activity {
        case .track(let track)?:
            XCTAssertEqual(track.event, "anon_no_identify_alpha")
        default:
            XCTFail("expected track oneof, got \(String(describing: activity.activity))")
        }
        XCTAssertTrue(DitoTrackDataManager().fetchOfflinePersistedTracks().isEmpty)
    }

    func testTrackWithPendingIdentify_waitsInQueueWithoutOwnerAndSendsNothing() async throws {
        DeviceIdProvider.setForTests("device-track-pending-1")
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: "uid-pending-1", reference: nil, json: nil, send: false))
        let mock = MockMobileIngestClient()

        await trackAndWait(DitoTrack(client: mock), action: "pending_identify_evt")
        await waitForTrackRowsWithEvents(1)

        XCTAssertEqual(mock.activityCallCount, 0)
        let rows = DitoTrackDataManager().fetchOfflinePersistedTracks()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.anonymous, false)
    }

    func testTrackDuringIdentifyInProgress_sendsNothingAnonymously() async throws {
        DeviceIdProvider.setForTests("device-track-saving-1")
        DitoIdentifyOffline.shared.initiateIdentify()
        let mock = MockMobileIngestClient()
        let sut = DitoTrack(client: mock)

        let identifyFinished = LockedFlag()
        let completedEarly = expectation(description: "track completion before identify")
        completedEarly.isInverted = true
        let completedAfterIdentify = expectation(description: "track completion after identify")
        sut.track(data: DitoEvent(action: "saving_identify_evt", customData: nil)) { _ in
            if identifyFinished.isSet {
                completedAfterIdentify.fulfill()
            } else {
                completedEarly.fulfill()
            }
        }
        await fulfillment(of: [completedEarly], timeout: 0.3)
        XCTAssertEqual(mock.activityCallCount, 0)

        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: "uid-saving-1", reference: nil, json: nil, send: false))
        identifyFinished.set()
        DitoIdentifyOffline.shared.finishIdentify()
        await fulfillment(of: [completedAfterIdentify], timeout: 10)
        await waitForTrackRowsWithEvents(1)

        XCTAssertEqual(mock.activityCallCount, 0)
        XCTAssertEqual(DitoTrackDataManager().fetchOfflinePersistedTracks().first?.anonymous, false)
    }

    func testRegisterTokenWithPendingIdentify_waitsInQueueWithoutOwnerAndSendsNothing() async throws {
        DeviceIdProvider.setForTests("device-register-pending-1")
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: "uid-pending-2", reference: nil, json: nil, send: false))
        let mock = MockMobileIngestClient()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DitoNotification(client: mock).registerToken(token: "fcm-pending-identify") { _ in cont.resume() }
        }

        XCTAssertEqual(mock.activityCallCount, 0)
        let pending = try XCTUnwrap(DitoNotificationRegisterDataManager().fetch)
        XCTAssertTrue(pending.json?.contains("fcm-pending-identify") == true)
        XCTAssertNil(pending.anonymous)
    }

    private func tokenAndWait(_ sut: DitoNotification, token: String, register: Bool) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            if register {
                sut.registerToken(token: token) { _ in cont.resume() }
            } else {
                sut.unregisterToken(token: token) { _ in cont.resume() }
            }
        }
    }

    func testAnonymousRegisterAndUnregister_ingestFails_areQueuedAsAnonymous() async throws {
        DeviceIdProvider.setForTests("device-token-anon-fail-1")
        let mock = MockMobileIngestClient()
        mock.shouldSucceed = false
        let sut = DitoNotification(client: mock)

        await tokenAndWait(sut, token: "fcm-anon-fail-register", register: true)
        await tokenAndWait(sut, token: "fcm-anon-fail-unregister", register: false)

        XCTAssertEqual(mock.activityCallCount, 2)
        XCTAssertTrue(mock.allActivityRequests.allSatisfy { $0.userID.isEmpty })
        let register = try XCTUnwrap(DitoNotificationRegisterDataManager().fetch)
        XCTAssertEqual(register.anonymous, true)
        XCTAssertTrue(register.json?.contains("fcm-anon-fail-register") == true)
        let unregister = try XCTUnwrap(DitoNotificationUnregisterDataManager().fetch)
        XCTAssertTrue(unregister.anonymous)
        XCTAssertTrue(unregister.json?.contains("fcm-anon-fail-unregister") == true)
    }

    private func tokenRegisterCount(_ mock: MockMobileIngestClient, userId: String, token: String) -> Int {
        mock.allActivityRequests.filter { req in
            req.userID == userId && req.activities.contains { activity in
                guard let oneOf = activity.activity, case .tokenRegister(let reg) = oneOf else { return false }
                return reg.token == token
            }
        }.count
    }

    func testAnonymousRegisterFailsAfterIdentifyConfirmedDuringSend_tokenReachesUserOnceAndNothingIsQueued() async throws {
        DeviceIdProvider.setForTests("device-login-during-send-1")
        let userId = "uid-login-during-send-1"
        let token = "fcm-login-during-send"
        let loginMock = MockMobileIngestClient()
        let sut = DitoNotification(client: FailsAfterClient {
            DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: nil, send: true)
            DitoNotification(client: loginMock).registerLastToken()
        })

        await tokenAndWait(sut, token: token, register: true)
        await waitForActivityCalls(loginMock, count: 1)
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertNil(DitoNotificationRegisterDataManager().fetch)
        XCTAssertEqual(tokenRegisterCount(loginMock, userId: userId, token: token), 1)
    }

    func testAnonymousRegisterFailsWhileIdentifyBecomesPending_retrySendsTokenOnceWithUser() async throws {
        DeviceIdProvider.setForTests("device-pending-during-send-1")
        let userId = "uid-pending-during-send-1"
        let token = "fcm-pending-during-send"
        let signup = DitoSignupRequest(
            platformAppKey: Dito.appKey,
            sha1Signature: Dito.signature,
            userData: DitoUser(email: "pending-during-send@example.com")
        )
        let sut = DitoNotification(client: FailsAfterClient {
            DitoIdentifyDataManager.shared.save(id: userId, reference: nil, json: signup.toString, send: false)
        })

        await tokenAndWait(sut, token: token, register: true)
        let queued = try XCTUnwrap(DitoNotificationRegisterDataManager().fetch)
        XCTAssertNil(queued.anonymous)

        let mock = MockMobileIngestClient()
        await DitoRetry(client: mock).runLoadOffline()
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(tokenRegisterCount(mock, userId: userId, token: token), 1)
        XCTAssertEqual(tokenRegisterCount(mock, userId: "", token: token), 0)
        XCTAssertNil(DitoNotificationRegisterDataManager().fetch)
    }

    func testUnregisterOfOldToken_keepsNewerLastToken() async {
        DeviceIdProvider.setForTests("device-token-rotation-1")
        let sut = DitoNotification(client: MockMobileIngestClient())

        await tokenAndWait(sut, token: "fcm-rotation-new", register: true)
        await tokenAndWait(sut, token: "fcm-rotation-old", register: false)
        XCTAssertEqual(UserDefaults.lastPushToken, "fcm-rotation-new")

        await tokenAndWait(sut, token: "fcm-rotation-new", register: false)
        XCTAssertNil(UserDefaults.lastPushToken)
    }

    func testQueuedRegister_thenUnregisterSameTokenSucceeds_retryDoesNotRegisterAgain() async throws {
        DeviceIdProvider.setForTests("device-register-then-unregister-1")
        let token = "fcm-register-then-unregister"
        let failing = MockMobileIngestClient()
        failing.shouldSucceed = false
        await tokenAndWait(DitoNotification(client: failing), token: token, register: true)
        XCTAssertNotNil(DitoNotificationRegisterDataManager().fetch)

        await tokenAndWait(DitoNotification(client: MockMobileIngestClient()), token: token, register: false)
        XCTAssertNil(DitoNotificationRegisterDataManager().fetch)

        let mock = MockMobileIngestClient()
        await DitoRetry(client: mock).runLoadOffline()
        XCTAssertEqual(tokenRegisterCount(mock, userId: "", token: token), 0)
    }

    func testQueuedUnregister_thenRegisterSameTokenSucceeds_retryDoesNotUnregister() async throws {
        DeviceIdProvider.setForTests("device-unregister-then-register-1")
        let token = "fcm-unregister-then-register"
        let failing = MockMobileIngestClient()
        failing.shouldSucceed = false
        await tokenAndWait(DitoNotification(client: failing), token: token, register: false)
        XCTAssertNotNil(DitoNotificationUnregisterDataManager().fetch)

        await tokenAndWait(DitoNotification(client: MockMobileIngestClient()), token: token, register: true)
        XCTAssertNil(DitoNotificationUnregisterDataManager().fetch)

        let mock = MockMobileIngestClient()
        await DitoRetry(client: mock).runLoadOffline()
        XCTAssertEqual(mock.activityCallCount, 0)
    }

    func testAnonymousUnregisterFailsAfterLoginDuringSend_isQueuedAsAnonymous() async throws {
        DeviceIdProvider.setForTests("device-unregister-login-during-send-1")
        let userId = "uid-unregister-login-during-send-1"
        let sut = DitoNotification(client: FailsAfterClient {
            DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: nil, send: true)
        })

        await tokenAndWait(sut, token: "fcm-unregister-login-during-send", register: false)

        let unregister = try XCTUnwrap(DitoNotificationUnregisterDataManager().fetch)
        XCTAssertTrue(unregister.anonymous)
    }

    func testAnonymousRegisterOfOldTokenFailsAfterLoginDuringSend_isDropped() async throws {
        DeviceIdProvider.setForTests("device-old-token-login-during-send-1")
        let userId = "uid-old-token-login-during-send-1"
        let sut = DitoNotification(client: FailsAfterClient {
            DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: nil, send: true)
            UserDefaults.lastPushToken = "fcm-newer-token"
        })

        await tokenAndWait(sut, token: "fcm-old-token-login-during-send", register: true)

        XCTAssertNil(DitoNotificationRegisterDataManager().fetch)
    }

    func testAnonymousUnregisterFails_tokenRegisteredAgainDuringSend_isDropped() async throws {
        DeviceIdProvider.setForTests("device-unregister-registered-again-1")
        let token = "fcm-unregister-registered-again"
        let sut = DitoNotification(client: FailsAfterClient {
            UserDefaults.lastPushToken = token
        })

        await tokenAndWait(sut, token: token, register: false)

        XCTAssertNil(DitoNotificationUnregisterDataManager().fetch)
    }

    func testRegisterSucceeds_logoutDuringSend_doesNotMarkTokenRegisteredForUser() async throws {
        DeviceIdProvider.setForTests("device-register-logout-during-send-1")
        let userId = "uid-register-logout-during-send-1"
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: nil, send: true))
        let sut = DitoNotification(client: SucceedsAfterClient {
            DitoIdentifyOffline.shared.logout()
        })

        await tokenAndWait(sut, token: "fcm-register-logout-during-send", register: true)

        XCTAssertNil(UserDefaults.lastUserTokenRegister)
    }

    func testIdentifiedRegisterFails_tokenReplacedDuringSend_isDropped() async throws {
        let userId = "uid-register-replaced-during-send-1"
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: nil, send: true))
        let sut = DitoNotification(client: FailsAfterClient {
            UserDefaults.lastPushToken = "fcm-register-replaced-newer"
        })

        await tokenAndWait(sut, token: "fcm-register-replaced-older", register: true)

        XCTAssertNil(DitoNotificationRegisterDataManager().fetch)
    }
    #endif

    func testRegisterRetryFails_newerRegisterSavedDuringSend_keepsItsRetry() async throws {
        let userId = "uid-register-retry-newer-1"
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: nil, send: true))
        XCTAssertTrue(DitoNotificationRegisterDataManager().save(
            with: makeTokenRequest(token: "fcm-register-retry-older").toString,
            retry: 2
        ))
        let newerJson = makeTokenRequest(token: "fcm-register-retry-newer").toString
        let client = FailsAfterClient {
            DitoNotificationRegisterDataManager().save(with: newerJson, retry: 0)
        }

        await DitoRetry(client: client).runLoadOffline()

        let pending = try XCTUnwrap(DitoNotificationRegisterDataManager().fetch)
        XCTAssertEqual(pending.json, newerJson)
        XCTAssertEqual(pending.retry, 0)
    }

    func testRegisterRetrySucceeds_logoutDuringSend_doesNotMarkTokenRegisteredForUser() async throws {
        let userId = "uid-register-retry-logout-1"
        let token = "fcm-register-retry-logout"
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: nil, send: true))
        UserDefaults.lastPushToken = token
        XCTAssertTrue(DitoNotificationRegisterDataManager().save(with: makeTokenRequest(token: token).toString, retry: 0))
        let client = SucceedsAfterClient {
            DitoIdentifyOffline.shared.logout()
        }

        await DitoRetry(client: client).runLoadOffline()

        XCTAssertNil(DitoNotificationRegisterDataManager().fetch)
        XCTAssertNil(UserDefaults.lastUserTokenRegister)
    }

    func testUnregisterRetrySucceeds_newerUnregisterSavedDuringSend_isKept() async throws {
        let userId = "uid-unregister-retry-newer-1"
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: nil, send: true))
        XCTAssertTrue(DitoNotificationUnregisterDataManager().save(
            with: makeTokenRequest(token: "fcm-unregister-retry-older").toString,
            retry: 0
        ))
        let newerJson = makeTokenRequest(token: "fcm-unregister-retry-newer").toString
        let client = SucceedsAfterClient {
            DitoNotificationUnregisterDataManager().save(with: newerJson, retry: 0)
        }

        await DitoRetry(client: client).runLoadOffline()

        let pending = try XCTUnwrap(DitoNotificationUnregisterDataManager().fetch)
        XCTAssertEqual(pending.json, newerJson)
    }

    func testIdentifyThenLoadOffline_sendsSingleBatchForPendingTracks() async throws {
        XCTAssertTrue(DitoTrackDataManager().fetchOfflinePersistedTracks().isEmpty)

        let trackClient = MockMobileIngestClient()
        let userId = "uid-offline-batch-1"

        DitoTrackOffline().completeTrack(event: makeEventRequest(action: "batch_evt_a"))
        DitoTrackOffline().completeTrack(event: makeEventRequest(action: "batch_evt_b"))

        await waitForTrackRowsWithEvents(2)
        let persistedBeforeIdentify = DitoTrackDataManager().fetchOfflinePersistedTracks()
        XCTAssertEqual(persistedBeforeIdentify.count, 2, "tracks should persist offline before identify")
        for row in persistedBeforeIdentify {
            XCTAssertNotNil(
                row.event.flatMap { $0.convertToObject(type: DitoEventRequest.self) },
                "persisted track JSON should decode"
            )
        }
        XCTAssertEqual(DitoTrackOffline().offlinePersistedTracks.count, 2)
        XCTAssertNil(DitoTrackOffline().reference)

        let signup = DitoSignupRequest(
            platformAppKey: Dito.appKey.isEmpty ? Dito.apiKey : Dito.appKey,
            sha1Signature: Dito.signature,
            userData: DitoUser(email: "batch@example.com")
        )
        guard let signupJson = signup.toString else {
            XCTFail("signup json")
            return
        }
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: signupJson, send: true))
        XCTAssertEqual(DitoIdentifyOffline.shared.getIdentify?.reference, userId)
        XCTAssertEqual(DitoTrackOffline().reference, userId)

        XCTAssertTrue(DitoIdentifyOffline.shared.getIdentify?.send == true)

        let retry = DitoRetry(client: trackClient)
        await retry.runLoadOffline()

        guard let batchReq = trackClient.allActivityRequests.first(where: { $0.activities.count >= 2 }) else {
            XCTFail(
                "expected one ingest request with at least 2 activities; callCount=\(trackClient.activityCallCount) sizes=\(trackClient.allActivityRequests.map { $0.activities.count })"
            )
            return
        }
        XCTAssertEqual(batchReq.userID, userId)
        XCTAssertGreaterThanOrEqual(batchReq.activities.count, 2)
        let trackActivities = batchReq.activities.filter { $0.type == .activityTrack }
        XCTAssertGreaterThanOrEqual(trackActivities.count, 2)
    }

    func testGetNotifications_returnsInsertedRecords() async throws {
        _ = DitoCoreDataManager.shared.persistentContainer

        let nid = "nid-getnotif-\(UUID().uuidString)"
        let title = "Título integração getNotifications"
        DitoNotificationCoreDataManager.shared.insert(
            notificationId: nid,
            title: title,
            message: "Corpo",
            link: "https://example.test/get"
        )

        try await Task.sleep(nanoseconds: 150_000_000)

        let list = Dito.shared.getNotifications()
        let match = list.first { $0.notificationId == nid }
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.title, title)
    }

    func testCoreDataMigration_fromModelWithoutAnonymous_keepsRowsWithNilAnonymous() throws {
        let currentModel = try XCTUnwrap(DitoCoreDataManager.shared.persistentContainer?.managedObjectModel)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dito-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("DitoDataModel.sqlite")

        let legacy = try loadContainer(model: makeLegacyModel(), storeURL: storeURL)
        let legacyContext = legacy.viewContext
        let track = NSEntityDescription.insertNewObject(forEntityName: "Track", into: legacyContext)
        track.setValue("{\"legacy\":\"track\"}", forKey: "event")
        track.setValue(NSNumber(value: Int16(2)), forKey: "retry")
        let unregister = NSEntityDescription.insertNewObject(forEntityName: "NotificationUnregister", into: legacyContext)
        unregister.setValue("{\"legacy\":\"unregister\"}", forKey: "json")
        unregister.setValue(NSNumber(value: Int16(1)), forKey: "retry")
        try legacyContext.save()
        for store in legacy.persistentStoreCoordinator.persistentStores {
            try legacy.persistentStoreCoordinator.remove(store)
        }

        let migrated = try loadContainer(model: currentModel, storeURL: storeURL)
        defer {
            for store in migrated.persistentStoreCoordinator.persistentStores {
                try? migrated.persistentStoreCoordinator.remove(store)
            }
        }
        let context = migrated.viewContext

        let tracks = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Track"))
        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks.first?.value(forKey: "event") as? String, "{\"legacy\":\"track\"}")
        XCTAssertEqual((tracks.first?.value(forKey: "retry") as? NSNumber)?.int16Value, 2)
        XCTAssertNil(tracks.first?.value(forKey: "anonymous"))

        let unregisters = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "NotificationUnregister"))
        XCTAssertEqual(unregisters.count, 1)
        XCTAssertEqual(unregisters.first?.value(forKey: "json") as? String, "{\"legacy\":\"unregister\"}")
        XCTAssertNil(unregisters.first?.value(forKey: "anonymous"))
    }

    private func loadContainer(model: NSManagedObjectModel, storeURL: URL) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "DitoDataModel", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        return container
    }

    private func makeLegacyModel() -> NSManagedObjectModel {
        func attribute(
            _ name: String,
            _ type: NSAttributeType,
            optional: Bool = true,
            defaultValue: Any? = nil
        ) -> NSAttributeDescription {
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.attributeType = type
            attribute.isOptional = optional
            attribute.defaultValue = defaultValue
            return attribute
        }
        func retry() -> NSAttributeDescription {
            attribute("retry", .integer16AttributeType, defaultValue: NSNumber(value: Int16(0)))
        }
        func entity(_ name: String, _ attributes: [NSAttributeDescription]) -> NSEntityDescription {
            let entity = NSEntityDescription()
            entity.name = name
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
            entity.properties = attributes
            return entity
        }

        let model = NSManagedObjectModel()
        model.entities = [
            entity("Identify", [
                attribute("id", .stringAttributeType),
                attribute("json", .stringAttributeType),
                attribute("reference", .stringAttributeType),
                attribute("send", .booleanAttributeType),
            ]),
            entity("IdentifySaveStamp", [
                attribute("timeStamp", .doubleAttributeType, defaultValue: NSNumber(value: 0.0)),
            ]),
            entity("NotificationRead", [attribute("json", .stringAttributeType), retry()]),
            entity("NotificationReceive", [attribute("json", .stringAttributeType), retry()]),
            entity("NotificationRegister", [attribute("json", .stringAttributeType), retry()]),
            entity("NotificationUnregister", [attribute("json", .stringAttributeType), retry()]),
            entity("Track", [attribute("event", .stringAttributeType), retry()]),
            entity("DitoNotificationRecord", [
                attribute("id", .stringAttributeType, optional: false),
                attribute("isRead", .booleanAttributeType, optional: false, defaultValue: NSNumber(value: false)),
                attribute("link", .stringAttributeType, optional: false),
                attribute("message", .stringAttributeType, optional: false),
                attribute("notificationId", .stringAttributeType, optional: false),
                attribute("receivedAt", .dateAttributeType, optional: false),
                attribute("reference", .stringAttributeType, optional: false),
                attribute("title", .stringAttributeType, optional: false),
                attribute("image", .stringAttributeType),
                attribute("customData", .stringAttributeType),
            ]),
        ]
        return model
    }
}

private final class FailsAfterClient: MobileIngestClientProtocol, @unchecked Sendable {
    private let beforeFailing: () -> Void

    init(_ beforeFailing: @escaping () -> Void) {
        self.beforeFailing = beforeFailing
    }

    func activity(_ request: Mobileingest_V1_Request) async throws -> Mobileingest_V1_Response {
        beforeFailing()
        throw MobileIngestError(message: "falha depois de mudar o identify")
    }
}

private final class SucceedsAfterClient: MobileIngestClientProtocol, @unchecked Sendable {
    private let beforeSucceeding: () -> Void

    init(_ beforeSucceeding: @escaping () -> Void) {
        self.beforeSucceeding = beforeSucceeding
    }

    func activity(_ request: Mobileingest_V1_Request) async throws -> Mobileingest_V1_Response {
        beforeSucceeding()
        return Mobileingest_V1_Response()
    }
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }
}
