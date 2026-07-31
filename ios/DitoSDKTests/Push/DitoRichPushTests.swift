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

    /// Espera pela activity de clique **desta** notificação.
    ///
    /// Esperar por uma contagem não serve: um clique ainda em voo de um teste
    /// anterior pode aterrar neste mock — `DitoNotification` lê o cliente de teste
    /// no init — e satisfazer a contagem com o pedido errado.
    private func waitForClickData(
        _ mock: MockMobileIngestClient,
        notificationId: String,
        timeout: TimeInterval = 10
    ) async -> [String: String] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let click = clickActivity(mock, notificationId: notificationId) {
                return click.data.mapValues { $0.single.stringValue }
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("timeout à espera do clique de \(notificationId)")
        return [:]
    }

    private func clickActivity(
        _ mock: MockMobileIngestClient,
        notificationId: String
    ) -> Mobileingest_V1_Activity.TrackPushClickActivity? {
        for request in mock.allActivityRequests {
            for activity in request.activities {
                guard case .trackPushClick(let click)? = activity.activity,
                      click.notification.notificationID == notificationId
                else { continue }
                return click
            }
        }
        return nil
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

        let data = await waitForClickData(mock, notificationId: nid)
        let types = mock.allActivityRequests.flatMap(\.activities).map(\.type)
        XCTAssertTrue(
            types.contains(.activityTrack),
            "D-03: continua a ser o evento de clique existente"
        )
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

        let data = await waitForClickData(mock, notificationId: nid)
        XCTAssertNil(data["action_id"])
        XCTAssertNil(data["action_label"])
    }

    /// Um toque no corpo chega como `UNNotificationDefaultActionIdentifier`
    /// e não pode ser confundido com um botão.
    func test_notificationClick_comIdentificadorDeSistema_naoRegistaAction() async throws {
        let mock = MockMobileIngestClient()
        DitoNotification.testMobileIngestClient = mock
        addTeardownBlock { DitoNotification.testMobileIngestClient = nil }

        let nid = "nid-\(UUID().uuidString)"
        let received = Dito.notificationClick(
            userInfo: [
                "notification": nid,
                "user_id": "user-\(UUID().uuidString)",
                "actions": Self.actionsJson,
            ],
            actionIdentifier: UNNotificationDefaultActionIdentifier
        )

        XCTAssertTrue(received.actionId.isEmpty)
        let data = await waitForClickData(mock, notificationId: nid)
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
            event: .received,
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
        XCTAssertEqual(object["event"] as? String, "received", "recebimento e clique têm de ser distinguíveis")
        XCTAssertEqual(object["source"] as? String, "nse")
        XCTAssertEqual(object["notification"] as? String, "nid-123")
        XCTAssertEqual(object["log_id"] as? String, "log-456")
        XCTAssertEqual(object["has_image"] as? Bool, true)
        XCTAssertEqual(object["action_ids"] as? [String], ["comprar_agora", "ver_depois"])
        XCTAssertEqual(object["custom_data_keys"] as? [String], ["id_pedido", "nivel_programa"])
    }

    func test_pushDebugLog_comPayloadNaoSerializavel_naoQuebra() {
        let line = DitoPushDebugLog.line(
            event: .clicked,
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

    /// A identidade do utilizador não pode sair no log: `os_log` é persistido e
    /// viaja num sysdiagnose.
    func test_pushDebugLog_linhaCrua_redigeIdentidadeEPreservaVazios() throws {
        let raw = DitoPushDebugLog.rawLine(userInfo: [
            "notification": "nid",
            "user_id": "user-real-123",
            "reference": "",
            "token": "fcm-abc",
            "data": ["identifier": "user-real-123", "custom_data": Self.customDataJson] as [String: Any],
        ])

        XCTAssertFalse(raw.contains("user-real-123"), "user_id não pode aparecer em claro")
        XCTAssertFalse(raw.contains("fcm-abc"), "token não pode aparecer em claro")
        XCTAssertTrue(raw.contains("<redacted>"))

        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: XCTUnwrap(raw.data(using: .utf8))) as? [String: Any]
        )
        XCTAssertEqual(object["reference"] as? String, "", "campo vazio fica visível: é o sinal que se vai ler")
        let nested = try XCTUnwrap(object["data"] as? [String: Any])
        XCTAssertEqual(nested["identifier"] as? String, "<redacted>", "a redacção desce aos sub-dicionários")
        XCTAssertEqual(object["notification"] as? String, "nid")
    }

    /// A credencial da plataforma viaja **dentro do payload** do push: numa campanha
    /// real de produção o `userInfo` chegou com `api_key` ao lado de `notification_name`
    /// e da lista de acções. Tudo que chega ao `userInfo` chega a este dump, então a
    /// chave tem de ser redigida como a identidade é.
    func test_pushDebugLog_linhaCrua_redigeCredenciais() throws {
        let raw = DitoPushDebugLog.rawLine(userInfo: [
            "notification": "nid",
            "api_key": "chave-de-plataforma-real",
            "api_secret": "secret-real",
            "signature": "sha1-real",
            "data": ["api_key": "chave-de-plataforma-real"] as [String: Any],
        ])

        XCTAssertFalse(raw.contains("chave-de-plataforma-real"), "api_key não pode aparecer em claro")
        XCTAssertFalse(raw.contains("secret-real"), "api_secret não pode aparecer em claro")
        XCTAssertFalse(raw.contains("sha1-real"), "signature não pode aparecer em claro")

        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: XCTUnwrap(raw.data(using: .utf8))) as? [String: Any]
        )
        XCTAssertEqual(object["api_key"] as? String, "<redacted>")
        let nested = try XCTUnwrap(object["data"] as? [String: Any])
        XCTAssertEqual(nested["api_key"] as? String, "<redacted>", "a redacção desce ao data aninhado")
        XCTAssertEqual(object["notification"] as? String, "nid", "o que não é segredo continua legível")
    }

    /// A linha pública não pode conter o payload cru.
    func test_pushDebugLog_linhaPublica_naoCarregaPayloadCru() {
        let line = DitoPushDebugLog.line(
            event: .received,
            source: .app,
            userInfo: ["notification": "nid", "user_id": "user-real-123"]
        )

        XCTAssertFalse(line.contains("user-real-123"))
        XCTAssertFalse(line.contains("\"raw\""))
    }

    // MARK: - Categoria de acções

    /// Mesmos ids com labels diferentes têm de dar categorias diferentes: a
    /// categoria é estado global e re-registá-la reescreveria os botões de
    /// notificações que já estão na bandeja.
    func test_categoryIdentifier_variaComOsLabels() {
        let first = DitoRichPushPayload(
            userInfo: ["actions": #"[{"id":"botao_1","label":"Comprar","link":"https://a"}]"#]
        )
        let second = DitoRichPushPayload(
            userInfo: ["actions": #"[{"id":"botao_1","label":"Resgatar","link":"https://a"}]"#]
        )
        let third = DitoRichPushPayload(
            userInfo: ["actions": #"[{"id":"botao_1","label":"Comprar","link":"https://b"}]"#]
        )

        XCTAssertNotEqual(first.categoryIdentifier, second.categoryIdentifier, "label diferente")
        XCTAssertNotEqual(first.categoryIdentifier, third.categoryIdentifier, "link diferente")
        XCTAssertTrue(first.categoryIdentifier?.hasPrefix("dito.actions.botao_1.") == true)
    }

    /// Cada entrega corre num processo novo, por isso o fingerprint tem de ser
    /// estável entre processos. Fixar o valor apanha uma troca acidental por
    /// `Hasher`, que é semeado por processo.
    func test_categoryFingerprint_ehEstavelEntreProcessos() {
        let actions = [DitoPushAction(id: "comprar_agora", label: "Comprar agora", link: "https://a")]

        XCTAssertEqual(
            DitoRichPushPayload.fingerprint(of: actions),
            DitoRichPushPayload.fingerprint(of: actions)
        )
        XCTAssertEqual(
            DitoRichPushPayload(userInfo: ["actions": Self.actionsJson]).categoryIdentifier,
            "dito.actions.comprar_agora.ver_depois."
                + DitoRichPushPayload.fingerprint(of: [
                    DitoPushAction(id: "comprar_agora", label: "Comprar agora", link: "https://loja.example/promo"),
                    DitoPushAction(id: "ver_depois", label: "Ver depois", link: "https://loja.example/depois"),
                ])
        )
    }

    /// A poda não pode apagar categorias da app hospedeira nem as que ainda
    /// estão a ser usadas por uma notificação na bandeja.
    func test_prune_removeApenasCategoriasDitoNaoUsadas() {
        let appOwn = UNNotificationCategory(
            identifier: "APP_PROPRIA", actions: [], intentIdentifiers: [], options: []
        )
        let ditoStale = UNNotificationCategory(
            identifier: "dito.actions.velha.abc", actions: [], intentIdentifiers: [], options: []
        )
        let ditoOnScreen = UNNotificationCategory(
            identifier: "dito.actions.na_bandeja.def", actions: [], intentIdentifiers: [], options: []
        )
        let ditoBeingRefreshed = UNNotificationCategory(
            identifier: "dito.actions.actual.ghi", actions: [], intentIdentifiers: [], options: []
        )

        let kept = DitoNotificationService.prune(
            [appOwn, ditoStale, ditoOnScreen, ditoBeingRefreshed],
            refreshing: "dito.actions.actual.ghi",
            stillOnScreen: ["dito.actions.na_bandeja.def"]
        )
        let identifiers = Set(kept.map(\.identifier))

        XCTAssertTrue(identifiers.contains("APP_PROPRIA"), "categoria da app nunca é tocada")
        XCTAssertTrue(identifiers.contains("dito.actions.na_bandeja.def"), "ainda visível: manter")
        XCTAssertFalse(identifiers.contains("dito.actions.velha.abc"), "órfã: remover")
        XCTAssertFalse(
            identifiers.contains("dito.actions.actual.ghi"),
            "a que está a ser re-registada sai daqui e é reinserida pelo chamador"
        )
    }

    // MARK: - Extensão do anexo

    /// É este método que decide se a imagem renderiza: `UNNotificationAttachment`
    /// valida pela extensão do ficheiro.
    func test_resolveFileExtension_matriz() {
        let png = URL(string: "https://cdn.example/banner.png")!
        let noExtension = URL(string: "https://cdn.example/imagem")!
        let queryOnly = URL(string: "https://cdn.example/asset.aspx?id=1")!

        XCTAssertEqual(
            DitoNotificationService.resolveFileExtension(url: png, response: nil),
            "png",
            "extensão do path ganha"
        )
        XCTAssertEqual(
            DitoNotificationService.resolveFileExtension(url: noExtension, response: mimeResponse("image/jpeg")),
            "jpeg",
            "sem extensão no path decide o mime"
        )
        XCTAssertEqual(
            DitoNotificationService.resolveFileExtension(url: queryOnly, response: mimeResponse("image/gif")),
            "gif",
            "extensão que não é de imagem cede ao mime"
        )
        XCTAssertEqual(
            DitoNotificationService.resolveFileExtension(url: noExtension, response: nil),
            "png",
            "sem sinal nenhum, último recurso"
        )
        XCTAssertEqual(
            DitoNotificationService.resolveFileExtension(url: noExtension, response: mimeResponse("nao/existe")),
            "png",
            "mime desconhecido cai no último recurso em vez de gerar extensão inválida"
        )
    }

    func test_makeAttachment_acimaDoLimite_naoAnexaEApagaOFicheiro() throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("dito-test-\(UUID().uuidString).png")
        try Data(repeating: 0, count: 2048).write(to: source)

        let attachment = DitoNotificationService.makeAttachment(
            from: source,
            url: URL(string: "https://cdn.example/grande.png")!,
            response: nil,
            maxBytes: 1024
        )

        XCTAssertNil(attachment, "acima do limite não vira anexo")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: source.path),
            "o ficheiro descarregado não pode ficar para trás"
        )
    }

    private func mimeResponse(_ mimeType: String) -> URLResponse {
        URLResponse(
            url: URL(string: "https://cdn.example/imagem")!,
            mimeType: mimeType,
            expectedContentLength: 1,
            textEncodingName: nil
        )
    }

    // MARK: - Chaves reservadas (D-03)

    /// `action_id` passa o filtro de chave válida, por isso uma campanha pode
    /// declará-lo — e não pode ganhar da acção realmente tocada.
    func test_customData_comChaveReservada_descartaAChaveDaCampanha() {
        let payload = DitoRichPushPayload(userInfo: [
            "custom_data": #"{"action_id":"falso","action_label":"Falso","nivel_programa":"ouro"}"#,
        ])

        XCTAssertNil(payload.customData[DitoRichPushKeys.actionId])
        XCTAssertNil(payload.customData[DitoRichPushKeys.actionLabel])
        XCTAssertEqual(payload.customData, ["nivel_programa": "ouro"])
    }

    func test_notificationClick_comChaveReservadaNaCampanha_enviaAAccaoTocada() async throws {
        let mock = MockMobileIngestClient()
        DitoNotification.testMobileIngestClient = mock
        addTeardownBlock { DitoNotification.testMobileIngestClient = nil }

        let nid = "nid-\(UUID().uuidString)"
        _ = Dito.notificationClick(
            userInfo: [
                "notification": nid,
                "user_id": "user-\(UUID().uuidString)",
                "actions": Self.actionsJson,
                "custom_data": #"{"action_id":"falso"}"#,
            ],
            actionIdentifier: "comprar_agora"
        )

        let data = await waitForClickData(mock, notificationId: nid)
        XCTAssertEqual(data["action_id"], "comprar_agora", "ganha a acção tocada, não a chave da campanha")
    }

    // MARK: - `reference` retirado do payload

    /// O campo está em retirada e a atribuição ancora em `user_id`; um payload
    /// que ainda o traga tem de ser ignorado de ponta a ponta.
    func test_payload_comReference_naoPropagaOCampo() throws {
        let userInfo: [AnyHashable: Any] = [
            "notification": "nid-ref",
            "user_id": "uid-ref",
            "reference": "ref-que-deve-ser-ignorada",
            "title": "t",
            "message": "m",
        ]

        let data = DitoDataNotification(from: userInfo)
        XCTAssertTrue(data.reference.isEmpty, "não é lido do payload")

        let encoded = try JSONEncoder().encode(data)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(
            object["reference"] as? String,
            "",
            "a chave continua no formato persistido, mas vazia"
        )
        XCTAssertFalse(
            String(decoding: encoded, as: UTF8.self).contains("ref-que-deve-ser-ignorada")
        )
    }

    func test_inbox_naoPersisteReferenceDoPayload() throws {
        let nid = "nid-inbox-ref-\(UUID().uuidString)"
        Dito.notificationReceived(
            userInfo: [
                "notification": nid,
                "user_id": "uid-\(UUID().uuidString)",
                "reference": "ref-ignorada",
                "title": "Título",
                "message": "Corpo",
            ],
            token: "fcm-token-teste"
        )
        TestHelpers.sleep(0.3)

        let record = try XCTUnwrap(
            DitoNotificationCoreDataManager.shared.getAll().first { $0.notificationId == nid }
        )
        XCTAssertEqual(record.reference, "", "a coluna existe mas não recebe o valor do payload")
    }
}
