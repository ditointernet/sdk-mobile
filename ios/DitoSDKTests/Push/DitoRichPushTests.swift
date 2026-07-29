import UserNotifications
import XCTest
@testable import DitoSDK
@testable import DitoSDKNotificationService

/// Rich push: image, action buttons and custom data (E4).
///
/// The payload is untrusted input, so parsing is asserted both for the happy
/// path defined by the backend contract and for payloads that break it.
final class DitoRichPushTests: XCTestCase {

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
        DitoPushDebugLog.resetEnabledOverride()
        TestHelpers.resetAllState()
        Dito.appKey = ""
        Dito.appSecret = ""
        Dito.signature = ""
        Dito.apiKey = ""
        Dito.bundleId = ""
        super.tearDown()
    }

    // MARK: Helpers

    private static let actionsJson = """
        [{"id":"comprar_agora","label":"Comprar agora","link":"https://loja.example/promo"},\
        {"id":"ver_depois","label":"Ver depois","link":"https://loja.example/depois"}]
        """

    private static let customDataJson = """
        {"nivel_programa":"ouro","id_pedido":"12345"}
        """

    private func waitForActivityCalls(
        _ mock: MockMobileIngestClient,
        count: Int,
        timeout: TimeInterval = 10
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if mock.activityCallCount >= count { return }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("timed out waiting for \(count) ingest call(s); got \(mock.activityCallCount)")
    }

    private func clickDataMap(_ request: Mobileingest_V1_Request) throws -> [String: String] {
        let activity = try XCTUnwrap(request.activities.first)
        guard case .trackPushClick(let click)? = activity.activity else {
            XCTFail("expected trackPushClick, got \(String(describing: activity.activity))")
            return [:]
        }
        var result: [String: String] = [:]
        for (key, value) in click.data {
            result[key] = value.single.stringValue
        }
        return result
    }

    // MARK: - T4.3 payload parsing

    func test_richPushPayload_comImagemActionsECustomData_parseiaTodosOsCampos() {
        let payload = DitoRichPushPayload(userInfo: [
            "image": "https://cdn.example/banner.png",
            "actions": Self.actionsJson,
            "custom_data": Self.customDataJson,
        ])

        XCTAssertEqual(payload.imageURL?.absoluteString, "https://cdn.example/banner.png")
        XCTAssertEqual(payload.actions.count, 2)
        XCTAssertEqual(payload.actions[0], DitoPushAction(
            id: "comprar_agora",
            label: "Comprar agora",
            link: "https://loja.example/promo"
        ))
        XCTAssertEqual(payload.actions[1].id, "ver_depois")
        XCTAssertEqual(payload.customData, ["nivel_programa": "ouro", "id_pedido": "12345"])
    }

    /// Degradação graciosa: um push legado não ganha nenhum campo rich.
    func test_richPushPayload_semCamposRich_ficaVazio() {
        let payload = DitoRichPushPayload(userInfo: TestHelpers.createMockUserInfo())

        XCTAssertTrue(payload.isEmpty)
        XCTAssertNil(payload.imageURL)
        XCTAssertFalse(payload.hasActions)
        XCTAssertNil(payload.categoryIdentifier)
        XCTAssertTrue(payload.customData.isEmpty)
    }

    func test_richPushPayload_comChavesNoSubDicionarioData_parseiaIgualmente() {
        let payload = DitoRichPushPayload(userInfo: [
            "data": [
                "image": "https://cdn.example/nested.png",
                "actions": Self.actionsJson,
            ] as [String: Any]
        ])

        XCTAssertEqual(payload.imageURL?.absoluteString, "https://cdn.example/nested.png")
        XCTAssertEqual(payload.actions.count, 2)
    }

    func test_richPushPayload_comImagemEmFcmOptions_parseiaImagem() {
        let payload = DitoRichPushPayload(userInfo: [
            "fcm_options": ["image": "https://cdn.example/fcm.jpg"] as [String: Any]
        ])

        XCTAssertEqual(payload.imageURL?.absoluteString, "https://cdn.example/fcm.jpg")
    }

    func test_richPushPayload_comActionsJsonInvalido_ignoraActionsSemQuebrar() {
        let payload = DitoRichPushPayload(userInfo: [
            "actions": "isto não é json",
            "custom_data": "{{{",
        ])

        XCTAssertTrue(payload.actions.isEmpty)
        XCTAssertTrue(payload.customData.isEmpty)
    }

    func test_richPushPayload_comMaisDeDuasActions_limitaADuas() {
        let json = """
            [{"id":"um","label":"Um","link":"https://a"},\
            {"id":"dois","label":"Dois","link":"https://b"},\
            {"id":"tres","label":"Tres","link":"https://c"}]
            """
        let payload = DitoRichPushPayload(userInfo: ["actions": json])

        XCTAssertEqual(payload.actions.map(\.id), ["um", "dois"])
    }

    func test_richPushPayload_comActionIdForaDoPadrao_descartaApenasAquelaAction() {
        let json = """
            [{"id":"Comprar Agora","label":"Inválido","link":"https://a"},\
            {"id":"ver_depois","label":"Válido","link":"https://b"}]
            """
        let payload = DitoRichPushPayload(userInfo: ["actions": json])

        XCTAssertEqual(payload.actions.map(\.id), ["ver_depois"])
    }

    func test_richPushPayload_comActionIdsDuplicados_mantemApenasOPrimeiro() {
        let json = """
            [{"id":"repetido","label":"Primeiro","link":"https://a"},\
            {"id":"repetido","label":"Segundo","link":"https://b"}]
            """
        let payload = DitoRichPushPayload(userInfo: ["actions": json])

        XCTAssertEqual(payload.actions.count, 1)
        XCTAssertEqual(payload.actions[0].label, "Primeiro")
    }

    func test_richPushPayload_comLabelAcimaDoLimite_truncaEm25Caracteres() {
        let longLabel = String(repeating: "a", count: 40)
        let json = #"[{"id":"acao","label":"\#(longLabel)","link":"https://a"}]"#
        let payload = DitoRichPushPayload(userInfo: ["actions": json])

        XCTAssertEqual(payload.actions.first?.label.count, 25)
    }

    func test_richPushPayload_comImagemNaoHttp_ignoraImagem() {
        for candidate in ["file:///etc/passwd", "data:image/png;base64,AAAA", "nao-e-url"] {
            let payload = DitoRichPushPayload(userInfo: ["image": candidate])
            XCTAssertNil(payload.imageURL, "esperava rejeitar \(candidate)")
        }
    }

    func test_richPushPayload_comCustomDataForaDoContrato_aplicaLimites() {
        var oversized: [String: String] = [:]
        for index in 0..<30 { oversized["chave_\(index)"] = "valor" }
        oversized["Chave-Inválida"] = "descartada"
        oversized["valor_longo"] = String(repeating: "v", count: 400)
        let json = String(
            data: try! JSONSerialization.data(withJSONObject: oversized),
            encoding: .utf8
        )!

        let payload = DitoRichPushPayload(userInfo: ["custom_data": json])

        XCTAssertEqual(payload.customData.count, 20, "no máximo 20 chaves")
        XCTAssertNil(payload.customData["Chave-Inválida"], "chave fora de ^[a-z0-9_]{1,40}$ é descartada")
        for value in payload.customData.values {
            XCTAssertLessThanOrEqual(value.count, 250)
        }
    }

    func test_categoryIdentifier_ehDeterministicoEVariaComOsIds() {
        let first = DitoRichPushPayload(userInfo: ["actions": Self.actionsJson])
        let second = DitoRichPushPayload(userInfo: ["actions": Self.actionsJson])
        let other = DitoRichPushPayload(
            userInfo: ["actions": #"[{"id":"outro","label":"Outro","link":"https://a"}]"#]
        )

        XCTAssertNotNil(first.categoryIdentifier)
        XCTAssertEqual(first.categoryIdentifier, second.categoryIdentifier)
        XCTAssertNotEqual(first.categoryIdentifier, other.categoryIdentifier)
    }

    func test_notificationReceived_comPayloadRich_exponeImagemActionsECustomData() {
        let received = DitoNotificationReceived(with: [
            "notification": "nid",
            "user_id": "uid",
            "link": "app://fallback",
            "image": "https://cdn.example/banner.png",
            "actions": Self.actionsJson,
            "custom_data": Self.customDataJson,
        ])

        XCTAssertEqual(received.image, "https://cdn.example/banner.png")
        XCTAssertEqual(received.actions.count, 2)
        XCTAssertEqual(received.customData["nivel_programa"], "ouro")
        XCTAssertEqual(received.resolvedLink, "app://fallback", "sem botão tocado usa o deeplink do push")
    }

    // MARK: - T4.4 / T4.5 contrato de clique (D-03)

    func test_notificationClick_comActionIdentifier_enviaActionIdEActionLabelNoDataMap() async throws {
        let mock = MockMobileIngestClient()
        DitoNotification.testMobileIngestClient = mock
        addTeardownBlock { DitoNotification.testMobileIngestClient = nil }

        let uid = "user-action-\(UUID().uuidString)"
        let nid = "nid-action-\(UUID().uuidString)"
        let userInfo: [AnyHashable: Any] = [
            "notification": nid,
            "user_id": uid,
            "link": "app://fallback",
            "actions": Self.actionsJson,
            "custom_data": Self.customDataJson,
        ]

        var callbackLink: String?
        let callbackExpectation = expectation(description: "callback do clique")
        let received = Dito.notificationClick(
            userInfo: userInfo,
            actionIdentifier: "comprar_agora"
        ) { link in
            callbackLink = link
            callbackExpectation.fulfill()
        }
        await fulfillment(of: [callbackExpectation], timeout: 2.0)

        XCTAssertEqual(received.actionId, "comprar_agora")
        XCTAssertEqual(received.actionLabel, "Comprar agora")
        XCTAssertEqual(callbackLink, "https://loja.example/promo", "o botão abre o seu próprio link")

        await waitForActivityCalls(mock, count: 1)
        let request = try XCTUnwrap(mock.lastActivityRequest)
        let activity = try XCTUnwrap(request.activities.first)
        XCTAssertEqual(activity.type, .activityTrack, "D-03: continua a ser o evento de clique existente")

        let data = try clickDataMap(request)
        XCTAssertEqual(data["action_id"], "comprar_agora")
        XCTAssertEqual(data["action_label"], "Comprar agora")
        XCTAssertEqual(data["nivel_programa"], "ouro", "custom data da campanha viaja junto")
    }

    func test_notificationClick_semActionIdentifier_naoEnviaActionNoDataMap() async throws {
        let mock = MockMobileIngestClient()
        DitoNotification.testMobileIngestClient = mock
        addTeardownBlock { DitoNotification.testMobileIngestClient = nil }

        let uid = "user-noaction-\(UUID().uuidString)"
        let nid = "nid-noaction-\(UUID().uuidString)"

        _ = Dito.notificationClick(userInfo: [
            "notification": nid,
            "user_id": uid,
            "actions": Self.actionsJson,
        ])

        await waitForActivityCalls(mock, count: 1)
        let data = try clickDataMap(try XCTUnwrap(mock.lastActivityRequest))
        XCTAssertNil(data["action_id"])
        XCTAssertNil(data["action_label"])
    }

    /// Um toque no corpo chega como `UNNotificationDefaultActionIdentifier`
    /// e não pode ser confundido com um botão.
    func test_notificationClick_comIdentificadorDeSistema_naoRegistaAction() async throws {
        let mock = MockMobileIngestClient()
        DitoNotification.testMobileIngestClient = mock
        addTeardownBlock { DitoNotification.testMobileIngestClient = nil }

        let received = Dito.notificationClick(
            userInfo: [
                "notification": "nid-\(UUID().uuidString)",
                "user_id": "user-\(UUID().uuidString)",
                "actions": Self.actionsJson,
            ],
            actionIdentifier: UNNotificationDefaultActionIdentifier
        )

        XCTAssertTrue(received.actionId.isEmpty)
        await waitForActivityCalls(mock, count: 1)
        let data = try clickDataMap(try XCTUnwrap(mock.lastActivityRequest))
        XCTAssertNil(data["action_id"])
    }

    func test_notificationClick_comActionIdentifierDesconhecido_ignoraAction() {
        let received = Dito.notificationClick(
            userInfo: [
                "notification": "nid",
                "user_id": "uid",
                "link": "app://fallback",
                "actions": Self.actionsJson,
            ],
            actionIdentifier: "botao_que_nao_existe"
        )

        XCTAssertTrue(received.actionId.isEmpty)
        XCTAssertEqual(received.resolvedLink, "app://fallback")
    }

    // MARK: - Compatibilidade da fila offline

    /// Linhas gravadas por uma versão anterior do SDK não têm as chaves rich.
    /// Se deixarem de descodificar, cliques em fila são descartados no upgrade.
    func test_ditoDataNotification_descodificaJsonLegadoSemCamposRich() throws {
        let legacyJson = """
            {"identifier":"uid","reference":"ref","notification":"nid","notification_log_id":"",\
            "user_id":"uid","device_type":"","channel":"","notification_name":"","title":"t",\
            "message":"m","link":"app://x","log_id":"lid"}
            """
        let data = try XCTUnwrap(legacyJson.data(using: .utf8))

        let decoded = try JSONDecoder().decode(DitoDataNotification.self, from: data)

        XCTAssertEqual(decoded.notification, "nid")
        XCTAssertEqual(decoded.link, "app://x")
        XCTAssertTrue(decoded.image.isEmpty)
        XCTAssertTrue(decoded.customData.isEmpty)
        XCTAssertTrue(decoded.clickCustomData.isEmpty)
    }

    func test_ditoDataNotification_comAction_fazRoundTripPreservandoAction() throws {
        let original = DitoDataNotification(
            from: [
                "notification": "nid",
                "user_id": "uid",
                "custom_data": Self.customDataJson,
            ],
            actionId: "comprar_agora",
            actionLabel: "Comprar agora"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DitoDataNotification.self, from: encoded)

        XCTAssertEqual(decoded.actionId, "comprar_agora")
        XCTAssertEqual(decoded.actionLabel, "Comprar agora")
        XCTAssertEqual(decoded.clickCustomData["action_label"], "Comprar agora")
        XCTAssertEqual(decoded.clickCustomData["id_pedido"], "12345")
    }

    /// Um push sem campos rich tem de continuar a serializar exactamente como antes.
    func test_ditoDataNotification_semCamposRich_naoEscreveChavesNovas() throws {
        let data = DitoDataNotification(from: TestHelpers.createMockUserInfo())

        let encoded = try JSONEncoder().encode(data)
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )

        XCTAssertNil(object["image"])
        XCTAssertNil(object["custom_data"])
        XCTAssertNil(object["action_id"])
        XCTAssertNil(object["action_label"])
    }

    // MARK: - T4.6 inbox

    func test_inbox_persisteEDevolveImagemECustomData() throws {
        let nid = "nid-inbox-\(UUID().uuidString)"
        DitoNotificationCoreDataManager.shared.insert(
            notificationId: nid,
            reference: "ref-inbox",
            title: "Título",
            message: "Corpo",
            link: "https://example.test/inbox",
            image: "https://cdn.example/inbox.png",
            customData: ["nivel_programa": "ouro"]
        )
        TestHelpers.sleep(0.15)

        let record = try XCTUnwrap(
            Dito.shared.getNotifications().first { $0.notificationId == nid }
        )
        XCTAssertEqual(record.image, "https://cdn.example/inbox.png")
        XCTAssertEqual(record.customData, ["nivel_programa": "ouro"])
    }

    func test_inbox_semCamposRich_devolveValoresVazios() throws {
        let nid = "nid-inbox-plain-\(UUID().uuidString)"
        DitoNotificationCoreDataManager.shared.insert(
            notificationId: nid,
            reference: "ref-inbox",
            title: "Título",
            message: "Corpo",
            link: "https://example.test/inbox"
        )
        TestHelpers.sleep(0.15)

        let record = try XCTUnwrap(
            Dito.shared.getNotifications().first { $0.notificationId == nid }
        )
        XCTAssertTrue(record.image.isEmpty)
        XCTAssertTrue(record.customData.isEmpty)
    }

    // MARK: - T9.1 dump do payload

    func test_pushDebugLog_linha_temPrefixoEstavelECorpoJsonParseavel() throws {
        let line = DitoPushDebugLog.line(
            source: .notificationServiceExtension,
            userInfo: [
                "notification": "nid-123",
                "log_id": "log-456",
                "image": "https://cdn.example/banner.png",
                "actions": Self.actionsJson,
                "custom_data": Self.customDataJson,
            ]
        )

        XCTAssertFalse(line.contains("\n"), "o dump tem de caber numa única linha")
        XCTAssertTrue(line.hasPrefix("DITO_PUSH_PAYLOAD "))
        XCTAssertEqual(DitoPushDebugLog.prefix, "DITO_PUSH_PAYLOAD")

        let json = String(line.dropFirst("DITO_PUSH_PAYLOAD ".count))
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: XCTUnwrap(json.data(using: .utf8))) as? [String: Any]
        )
        XCTAssertEqual(object["source"] as? String, "nse")
        XCTAssertEqual(object["notification"] as? String, "nid-123")
        XCTAssertEqual(object["log_id"] as? String, "log-456")
        XCTAssertEqual(object["has_image"] as? Bool, true)
        XCTAssertEqual(object["action_ids"] as? [String], ["comprar_agora", "ver_depois"])
        XCTAssertEqual(object["custom_data_keys"] as? [String], ["id_pedido", "nivel_programa"])
    }

    func test_pushDebugLog_comPayloadNaoSerializavel_naoQuebra() {
        let line = DitoPushDebugLog.line(
            source: .app,
            userInfo: ["notification": "nid", "objeto": Date()]
        )

        XCTAssertTrue(line.hasPrefix("DITO_PUSH_PAYLOAD "))
        XCTAssertFalse(line.contains("\n"))
    }

    func test_pushDebugLog_isEnabled_respeitaOverrideEReset() {
        let original = DitoPushDebugLog.isEnabled

        DitoPushDebugLog.isEnabled = true
        XCTAssertTrue(DitoPushDebugLog.isEnabled)
        DitoPushDebugLog.isEnabled = false
        XCTAssertFalse(DitoPushDebugLog.isEnabled)

        DitoPushDebugLog.resetEnabledOverride()
        XCTAssertEqual(DitoPushDebugLog.isEnabled, original)
    }
}
