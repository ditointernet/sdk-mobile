import XCTest
@testable import DitoSDK

final class DitoNotificationDataTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestHelpers.resetAllState()
        #if DEBUG
        DitoNotificationReceiveTracker.resetForTests()
        Dito.invalidateRetryCacheForTests()
        #endif
        Dito.appKey = "unit-test-app-key"
        Dito.appSecret = ""
        Dito.signature = "unit-test-signature"
        Dito.apiKey = ""
        Dito.bundleId = "br.com.dito.sdk.unit.tests"
        _ = DitoCoreDataManager.shared.persistentContainer
    }

    override func tearDown() {
        #if DEBUG
        Dito.testNotificationReceivedIngestClient = nil
        DitoNotification.testMobileIngestClient = nil
        #endif
        TestHelpers.resetAllState()
        Dito.appKey = ""
        Dito.appSecret = ""
        Dito.signature = ""
        Dito.apiKey = ""
        Dito.bundleId = ""
        super.tearDown()
    }

    #if DEBUG
    private func assertNoActivityIngestAfterDelay(mock: MockMobileIngestClient) async {
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(
            mock.activityCallCount,
            0,
            "D-08: sem user_id identificável, ingest de activities não é chamado; persistência local via Core Data mantém-se"
        )
    }

    private func waitForActivityCalls(_ mock: MockMobileIngestClient, count: Int, timeout: TimeInterval = 10) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if mock.activityCallCount >= count { return }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("timed out waiting for \(count) ingest call(s); got \(mock.activityCallCount)")
    }

    private func waitForNotificationReceiveRows(count: Int, timeout: TimeInterval = 10) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if DitoNotificationReceiveDataManager().fetchAll.count >= count { return }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail(
            "timed out waiting for \(count) NotificationReceive row(s); got \(DitoNotificationReceiveDataManager().fetchAll.count)"
        )
    }

    private func waitForRegisterPendingJson(
        _ dm: DitoNotificationRegisterDataManager,
        timeout: TimeInterval = 10
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let j = dm.fetch?.json, !j.isEmpty { return }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail(
            "T3.3: timeout \(timeout)s à espera de json em DitoNotificationRegisterDataManager; fetch=\(String(describing: dm.fetch))"
        )
    }

    private func makeSignupJsonForIdentify() -> String {
        let signup = DitoSignupRequest(
            platformAppKey: Dito.appKey.isEmpty ? Dito.apiKey : Dito.appKey,
            sha1Signature: Dito.signature,
            userData: DitoUser(email: "is-saving-token@example.com")
        )
        guard let json = signup.toString else {
            XCTFail("signup json")
            return ""
        }
        return json
    }

    func test_registerToken_comIsSavingTrueEIdentifyComReference_enviaActivityAposFinishIdentify() async throws {
        let activityWaitTimeout: TimeInterval = 10
        let savingPollTimeout: TimeInterval = 2

        let userId = "user-is-saving-token-\(UUID().uuidString)"
        let signupJson = makeSignupJsonForIdentify()
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: signupJson, send: true))

        DitoIdentifyOffline.shared.initiateIdentify()
        XCTAssertTrue(DitoNotificationOffline().isSaving, "T3.3: initiateIdentify deve activar isSaving (stamp)")

        let mock = MockMobileIngestClient()
        DitoNotification.testMobileIngestClient = mock
        addTeardownBlock { DitoNotification.testMobileIngestClient = nil }

        let registerDM = DitoNotificationRegisterDataManager()
        XCTAssertNil(registerDM.fetch?.json, "T3.3: antes de registerToken não há registo pendente em UserDefaults")

        let token = "fcm-is-saving-\(UUID().uuidString)"
        let sut = DitoNotification()
        sut.registerToken(token: token)

        XCTAssertTrue(DitoNotificationOffline().isSaving, "T3.3: registerToken com isSaving só enfileira; identify continua activo")
        XCTAssertEqual(mock.activityCallCount, 0, "T3.3: ingest não dispara antes de finishIdentify")
        XCTAssertNil(registerDM.fetch?.json, "T3.3: token ainda não persistido nem enviado antes do desbloqueio")

        DitoIdentifyOffline.shared.finishIdentify()
        XCTAssertFalse(DitoNotificationOffline().isSaving, "T3.3: finishIdentify deve limpar isSaving")

        await waitForActivityCalls(mock, count: 1, timeout: activityWaitTimeout)

        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, userId)
        let act = try XCTUnwrap(req.activities.first)
        guard let oneOf = act.activity, case .tokenRegister(let reg) = oneOf else {
            XCTFail("T3.3: esperado tokenRegister após desbloqueio; activity=\(String(describing: act.activity))")
            return
        }
        XCTAssertEqual(reg.token, token)
        XCTAssertNil(registerDM.fetch?.json, "T3.3: sucesso de ingest não deve deixar fila offline")

        try await Task.sleep(nanoseconds: UInt64(savingPollTimeout * 1_000_000_000))
        XCTAssertEqual(mock.activityCallCount, 1, "T3.3: D-08 — sem chamadas duplicadas de ingest")
    }

    func test_registerToken_comIsSavingTrueSemReference_persisteEmRegisterDMAposFinishIdentify() async throws {
        let registerWaitTimeout: TimeInterval = 10

        let userId = "user-sem-ref-\(UUID().uuidString)"
        let signupJson = makeSignupJsonForIdentify()
        XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: nil, json: signupJson, send: false))

        DitoIdentifyOffline.shared.initiateIdentify()
        XCTAssertTrue(DitoNotificationOffline().isSaving)

        let mock = MockMobileIngestClient()
        DitoNotification.testMobileIngestClient = mock
        addTeardownBlock { DitoNotification.testMobileIngestClient = nil }

        let registerDM = DitoNotificationRegisterDataManager()
        XCTAssertNil(registerDM.fetch?.json)

        let token = "fcm-offline-queue-\(UUID().uuidString)"
        DitoNotification().registerToken(token: token)

        XCTAssertEqual(mock.activityCallCount, 0)
        XCTAssertNil(registerDM.fetch?.json, "T3.3: com isSaving, persistência diferida até finishIdentify")

        DitoIdentifyOffline.shared.finishIdentify()

        await waitForRegisterPendingJson(registerDM, timeout: registerWaitTimeout)
        let savedJson = try XCTUnwrap(registerDM.fetch?.json)
        XCTAssertTrue(savedJson.contains(token), "T3.3: token serializado na fila offline")
        XCTAssertEqual(mock.activityCallCount, 0, "T3.3: sem user reference não há ingest síncrono de token")
    }

    func test_notificationReceived_semUserIdPersisteLocalmenteENaoEnviaActivityIngest() async throws {
        let mock = MockMobileIngestClient()
        Dito.testNotificationReceivedIngestClient = mock
        addTeardownBlock { Dito.testNotificationReceivedIngestClient = nil }

        let nid = "nid-sem-user-\(UUID().uuidString)"
        let reference = "ref-sem-user"
        let title = "Título sem user_id"
        let message = "Corpo"
        let link = "https://example.test/sem-user"

        let userInfo: [AnyHashable: Any] = [
            "notification": nid,
            "reference": reference,
            "title": title,
            "message": message,
            "link": link,
        ]

        XCTAssertTrue(DitoNotificationReceived(with: userInfo).userId.isEmpty)

        Dito.notificationReceived(userInfo: userInfo, token: "fcm-token-sem-user")

        await assertNoActivityIngestAfterDelay(mock: mock)

        try await Task.sleep(nanoseconds: 150_000_000)

        let list = Dito.shared.getNotifications()
        let match = list.first { $0.notificationId == nid }
        XCTAssertNotNil(match, "registo local via Core Data deve incluir a notificação")
        // `reference` deixou de ser lido do payload (campo em retirada; a
        // atribuição ancora em user_id), por isso não é asserido aqui.
        // Ver test_payload_comReference_naoPropagaOCampo em DitoRichPushTests.
        XCTAssertEqual(match?.title, title)
        XCTAssertEqual(match?.message, message)
        XCTAssertEqual(match?.link, link)
    }

    func test_notificationReceived_comUserIdVazioPersisteLocalmenteENaoEnviaActivityIngest() async throws {
        let mock = MockMobileIngestClient()
        Dito.testNotificationReceivedIngestClient = mock
        addTeardownBlock { Dito.testNotificationReceivedIngestClient = nil }

        let nid = "nid-user-vazio-\(UUID().uuidString)"
        let userInfo: [AnyHashable: Any] = [
            "user_id": "",
            "notification": nid,
            "reference": "ref-vazio",
            "title": "T",
            "message": "M",
            "link": "app://x",
        ]

        XCTAssertTrue(DitoNotificationReceived(with: userInfo).userId.isEmpty)

        Dito.notificationReceived(userInfo: userInfo, token: "fcm-token-vazio")

        await assertNoActivityIngestAfterDelay(mock: mock)

        try await Task.sleep(nanoseconds: 150_000_000)

        let list = Dito.shared.getNotifications()
        XCTAssertNotNil(list.first { $0.notificationId == nid })
    }

    func test_notificationClick_userInfoMinimoDisparaTrackPushClickEDeeplinkOpcionalNoCallback() async throws {
        let mock = MockMobileIngestClient()
        DitoNotification.testMobileIngestClient = mock
        addTeardownBlock { DitoNotification.testMobileIngestClient = nil }

        let uid = "user-click-\(UUID().uuidString)"
        let nid = "nid-click-\(UUID().uuidString)"
        let deeplink = "app://unit-test/promo"
        let userInfo: [AnyHashable: Any] = [
            "notification": nid,
            "user_id": uid,
            "link": deeplink,
        ]

        let parsed = DitoNotificationReceived(with: userInfo)
        XCTAssertEqual(parsed.notification, nid)
        XCTAssertEqual(parsed.identifier, uid)
        XCTAssertEqual(parsed.userId, uid)

        var callbackDeeplink: String?
        let callbackExpectation = expectation(description: "deeplink callback")
        _ = Dito.notificationClick(userInfo: userInfo) { link in
            callbackDeeplink = link
            callbackExpectation.fulfill()
        }
        await fulfillment(of: [callbackExpectation], timeout: 2.0)
        XCTAssertEqual(callbackDeeplink, deeplink)

        await waitForActivityCalls(mock, count: 1)

        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, uid)
        let a = try XCTUnwrap(req.activities.first)
        XCTAssertEqual(a.type, .activityTrack)
        switch a.activity {
        case .trackPushClick(let click)?:
            XCTAssertEqual(click.notification.notificationID, nid)
            XCTAssertEqual(click.notification.identifier, uid)
        default:
            XCTFail("expected trackPushClick, got \(String(describing: a.activity))")
        }
    }

    func test_notificationReceived_userIdCamelCaseEnviaActivityIngest() async throws {
        let mock = MockMobileIngestClient()
        Dito.testNotificationReceivedIngestClient = mock
        addTeardownBlock { Dito.testNotificationReceivedIngestClient = nil }

        let uid = "user-camel-\(UUID().uuidString)"
        let nid = "nid-camel-\(UUID().uuidString)"
        let userInfo: [AnyHashable: Any] = [
            "userId": uid,
            "notification": nid,
            "reference": "ref-camel",
            "log_id": "log-camel",
        ]

        XCTAssertEqual(DitoNotificationReceived(with: userInfo).userId, uid)

        Dito.notificationReceived(userInfo: userInfo, token: "fcm-token-camel")
        await waitForActivityCalls(mock, count: 1)

        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, uid)
    }

    /// Em primeiro plano `willPresent` e `didReceiveRemoteNotification` chamam este caminho para o
    /// mesmo push. A guarda antiga lia o estado de entrega antes do `await` da rede e só marcava
    /// depois dele, então as duas chegadas passavam.
    func test_notificationReceived_duasChegadasDoMesmoPush_enviamUmSoEvento() async throws {
        let mock = MockMobileIngestClient()
        Dito.testNotificationReceivedIngestClient = mock
        addTeardownBlock { Dito.testNotificationReceivedIngestClient = nil }

        let uid = "user-dedup-\(UUID().uuidString)"
        let nid = "nid-dedup-\(UUID().uuidString)"
        let userInfo: [AnyHashable: Any] = [
            "user_id": uid,
            "notification": nid,
            "log_id": "log-dedup",
            "title": "T",
            "message": "M",
        ]

        Dito.notificationReceived(userInfo: userInfo, token: "fcm-token-dedup")
        Dito.notificationReceived(userInfo: userInfo, token: "fcm-token-dedup")

        await waitForActivityCalls(mock, count: 1)
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(mock.activityCallCount, 1, "o segundo callback não deve gerar um segundo envio")
    }

    /// A linha duplicada ficava com `isRead == false` para sempre, inflando o contador de não-lidas.
    func test_notificationReceived_duasChegadasDoMesmoPush_criamUmaSoLinhaNoInbox() async throws {
        let mock = MockMobileIngestClient()
        Dito.testNotificationReceivedIngestClient = mock
        addTeardownBlock { Dito.testNotificationReceivedIngestClient = nil }

        let nid = "nid-inbox-dedup-\(UUID().uuidString)"
        let userInfo: [AnyHashable: Any] = [
            "user_id": "user-inbox-dedup-\(UUID().uuidString)",
            "notification": nid,
            "log_id": "log-inbox-dedup",
            "title": "T",
            "message": "M",
        ]

        Dito.notificationReceived(userInfo: userInfo, token: "fcm-token-inbox-dedup")
        Dito.notificationReceived(userInfo: userInfo, token: "fcm-token-inbox-dedup")
        try await Task.sleep(nanoseconds: 400_000_000)

        let rows = Dito.shared.getNotifications().filter { $0.notificationId == nid }
        XCTAssertEqual(rows.count, 1)
    }

    /// Sem devolver a reivindicação, um push cuja entrega falhou ficaria bloqueado até o processo
    /// morrer — e a nova chegada do mesmo push não teria como ser contada.
    func test_claimDelivery_reivindicaUmaVezEDevolveNoRelease() {
        let nid = "nid-claim-\(UUID().uuidString)"
        let logId = "log-claim"

        XCTAssertTrue(DitoNotificationReceiveTracker.claimDelivery(notification: nid, logId: logId))
        XCTAssertFalse(DitoNotificationReceiveTracker.claimDelivery(notification: nid, logId: logId))

        DitoNotificationReceiveTracker.releaseClaim(notification: nid, logId: logId)
        XCTAssertTrue(DitoNotificationReceiveTracker.claimDelivery(notification: nid, logId: logId))

        DitoNotificationReceiveTracker.markDelivered(notification: nid, logId: logId)
        XCTAssertFalse(
            DitoNotificationReceiveTracker.claimDelivery(notification: nid, logId: logId),
            "depois de entregue, nem o release deve reabrir"
        )
        DitoNotificationReceiveTracker.releaseClaim(notification: nid, logId: logId)
        XCTAssertFalse(DitoNotificationReceiveTracker.claimDelivery(notification: nid, logId: logId))
    }

    /// Sem par de identificadores não há chave de dedupe. Enviar duas vezes é uma falha menor que
    /// nunca enviar, então o caminho segue aberto.
    func test_claimDelivery_semIdentificadoresSempreLibera() {
        XCTAssertTrue(DitoNotificationReceiveTracker.claimDelivery(notification: "", logId: ""))
        XCTAssertTrue(DitoNotificationReceiveTracker.claimDelivery(notification: "", logId: ""))
    }

    func test_notificationReceived_userIdNumericoEnviaActivityIngest() async throws {
        let mock = MockMobileIngestClient()
        Dito.testNotificationReceivedIngestClient = mock
        addTeardownBlock { Dito.testNotificationReceivedIngestClient = nil }

        let uid = "987654"
        let nid = "nid-num-\(UUID().uuidString)"
        let userInfo: [AnyHashable: Any] = [
            "user_id": NSNumber(value: 987654),
            "notification": nid,
            "log_id": "log-num",
        ]

        XCTAssertEqual(DitoNotificationReceived(with: userInfo).userId, uid)

        Dito.notificationReceived(userInfo: userInfo, token: "fcm-token-num")
        await waitForActivityCalls(mock, count: 1)
        XCTAssertEqual(try XCTUnwrap(mock.lastActivityRequest).userID, uid)
    }

    func test_notificationReceived_completionAposIngest() async throws {
        let mock = MockMobileIngestClient()
        Dito.testNotificationReceivedIngestClient = mock
        addTeardownBlock { Dito.testNotificationReceivedIngestClient = nil }

        let uid = "user-cb-\(UUID().uuidString)"
        let nid = "nid-cb-\(UUID().uuidString)"
        let userInfo: [AnyHashable: Any] = [
            "user_id": uid,
            "notification": nid,
            "log_id": "log-cb",
        ]

        let completionExpectation = expectation(description: "receive completion")
        Dito.notificationReceived(userInfo: userInfo, token: "fcm-cb") { result in
            if case .success = result {
                completionExpectation.fulfill()
            }
        }
        await fulfillment(of: [completionExpectation], timeout: 10)
        await waitForActivityCalls(mock, count: 1)
    }

    func test_notificationReceived_userIdAninhadoEmDataEnviaActivityIngest() async throws {
        let mock = MockMobileIngestClient()
        Dito.testNotificationReceivedIngestClient = mock
        addTeardownBlock { Dito.testNotificationReceivedIngestClient = nil }

        let uid = "user-nested-\(UUID().uuidString)"
        let nid = "nid-nested-\(UUID().uuidString)"
        let userInfo: [AnyHashable: Any] = [
            "data": [
                "channel": "DITO",
                "user_id": uid,
                "notification": nid,
                "reference": "ref-nested",
                "log_id": "log-nested",
                "notification_name": "Nome",
            ],
        ]

        XCTAssertEqual(DitoNotificationReceived(with: userInfo).userId, uid)

        Dito.notificationReceived(userInfo: userInfo, token: "fcm-token-nested")
        await waitForActivityCalls(mock, count: 1)

        let req = try XCTUnwrap(mock.lastActivityRequest)
        XCTAssertEqual(req.userID, uid)
        let trackActivity = req.activities.first { $0.type == .activityTrack }
        switch trackActivity?.activity {
        case .track(let track)?:
            XCTAssertEqual(track.event, "receive-ios-notification")
        default:
            XCTFail("expected receive-ios-notification track activity")
        }
    }

    func test_notificationReceived_falhaIngestPersisteOfflineERetryEnvia() async throws {
        let failingMock = MockMobileIngestClient()
        failingMock.shouldSucceed = false
        Dito.testNotificationReceivedIngestClient = failingMock
        addTeardownBlock { Dito.testNotificationReceivedIngestClient = nil }

        let uid = "user-offline-\(UUID().uuidString)"
        let nid = "nid-offline-\(UUID().uuidString)"
        let userInfo: [AnyHashable: Any] = [
            "user_id": uid,
            "notification": nid,
            "reference": "ref-offline",
            "log_id": "log-offline",
            "notification_name": "Offline",
        ]

        await Dito.awaitNotificationReceivedDelivery(userInfo: userInfo, token: "fcm-offline")
        await waitForNotificationReceiveRows(count: 1)

        let successMock = MockMobileIngestClient()
        Dito.testNotificationReceivedIngestClient = successMock
        Dito.invalidateRetryCacheForTests()
        await Dito.shared.retry.runLoadOffline()
        await waitForActivityCalls(successMock, count: 1)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(DitoNotificationReceiveDataManager().fetchAll.isEmpty)
    }

    func test_notificationClick_comIdPresenteMarcaComoLidaAposIngestAssincrono() async throws {
        let receivedMock = MockMobileIngestClient()
        Dito.testNotificationReceivedIngestClient = receivedMock
        addTeardownBlock { Dito.testNotificationReceivedIngestClient = nil }

        let uid = "user-read-\(UUID().uuidString)"
        let nid = "nid-read-\(UUID().uuidString)"
        let userInfoReceived: [AnyHashable: Any] = [
            "notification": nid,
            "user_id": uid,
            "reference": "ref-read",
            "title": "Título",
            "message": "Corpo",
            "link": "https://example.test/read",
        ]

        Dito.notificationReceived(userInfo: userInfoReceived, token: "fcm-token-read")
        await waitForActivityCalls(receivedMock, count: 1)
        try await Task.sleep(nanoseconds: 150_000_000)

        let listBefore = Dito.shared.getNotifications()
        let rowBefore = try XCTUnwrap(listBefore.first { $0.notificationId == nid })
        XCTAssertFalse(rowBefore.isRead)

        let clickMock = MockMobileIngestClient()
        DitoNotification.testMobileIngestClient = clickMock
        addTeardownBlock { DitoNotification.testMobileIngestClient = nil }

        let userInfoClick: [AnyHashable: Any] = [
            "notification": nid,
            "user_id": uid,
        ]
        _ = Dito.notificationClick(userInfo: userInfoClick, callback: nil)

        await waitForActivityCalls(clickMock, count: 1)

        let listAfter = Dito.shared.getNotifications()
        let rowAfter = try XCTUnwrap(listAfter.first { $0.notificationId == nid })
        XCTAssertTrue(rowAfter.isRead)
    }
    #endif
}
