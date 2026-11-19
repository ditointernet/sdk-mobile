@testable import DitoSDK
import XCTest

// MARK: - Variantes de `configure` — mapa de estado estático (`Dito`)
//
// Pré-condição nos testes: `setUp` chama `Dito.resetFacadeIsolationState()` (DEBUG) antes de
// `setupTestEnvironment()`, deixando `appKey`, `appSecret`, `signature`, `apiKey` e `bundleId` vazios.
//
// **Variante 1 — `Dito.configure(appKey:appSecret:)`**
// - `appKey` → igual ao argumento `appKey`
// - `appSecret` → Base64(UTF-8 do argumento `appSecret` em texto plano)
// - `signature` → SHA-1 do argumento `appSecret` em texto plano (extensão `.sha1`)
// - `apiKey` → `""`
// - `bundleId` → `""`
//
// **Variante 2 — `Dito.configure(apiKey:bundleId:)`**
// - `apiKey` → igual ao argumento `apiKey`
// - `bundleId` → igual ao argumento `bundleId`
// - `appKey` → `""`
// - `appSecret` → `""`
// - `signature` → `""`
//
// Este ficheiro não importa `UserNotifications` nem constrói `UNNotificationContent`.

final class DitoFacadeTests: XCTestCase {

  override func setUp() {
    super.setUp()
    #if DEBUG
    Dito.resetFacadeIsolationState()
    #endif
    setupTestEnvironment()
  }

  override func tearDown() {
    #if DEBUG
    Dito.resetFacadeIsolationState()
    #endif
    teardownTestEnvironment()
    super.tearDown()
  }

  func testConfigure_withAppKeyAndAppSecret_setsKeySecretSignatureAndLeavesApiKeyPathEmpty() {
    let appKey = "facade-test-app-key"
    let appSecret = "facade-plain-secret"
    Dito.configure(appKey: appKey, appSecret: appSecret)

    let expectedB64 = (appSecret.data(using: .utf8) ?? Data()).base64EncodedString()
    assertFacadeStaticState(
      appKey: appKey,
      appSecret: expectedB64,
      signature: appSecret.sha1,
      apiKey: "",
      bundleId: ""
    )
  }

  func testConfigure_withApiKeyAndBundleId_setsApiKeyAndBundleIdAndLeavesAppKeyPathEmpty() {
    let apiKey = "facade-test-api-key"
    let bundleId = "br.com.dito.facade.tests"
    Dito.configure(apiKey: apiKey, bundleId: bundleId)

    assertFacadeStaticState(
      appKey: "",
      appSecret: "",
      signature: "",
      apiKey: apiKey,
      bundleId: bundleId
    )
  }

  func testLogout_removesLocalIdentityAndPreservesConfigurationAndInbox() {
    let appKey = "facade-logout-app-key"
    let appSecret = "facade-logout-secret"
    Dito.configure(appKey: appKey, appSecret: appSecret)
    Dito.setNotificationOptions(DitoNotificationOptions(soundName: "logout-sound.mp3"))

    let userId = "facade-logout-user"
    let signup = DitoSignupRequest(
      platformAppKey: appKey,
      sha1Signature: appSecret.sha1,
      userData: DitoUser(email: "logout@example.com")
    )
    XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: signup.toString, send: true))
    DitoIdentifyOffline.shared.initiateIdentify()

    var callbackCallCount = 0
    DitoIdentifyOffline.shared.setIdentityCompletionClosure {
      callbackCallCount += 1
    }

    let notificationId = "facade-logout-notification"
    DitoNotificationCoreDataManager.shared.insert(
      notificationId: notificationId,
      title: "Logout inbox",
      message: "Inbox deve permanecer",
      link: "https://example.test/logout"
    )
    TestHelpers.sleep(0.15)

    XCTAssertEqual(DitoTrackOffline().reference, userId)
    XCTAssertEqual(DitoNotificationOffline().reference, userId)
    XCTAssertTrue(DitoIdentifyOffline.shared.getSavingState)
    XCTAssertTrue(Dito.shared.getNotifications().contains { $0.notificationId == notificationId })

    Dito.logout()

    XCTAssertNil(DitoIdentifyOffline.shared.getIdentify)
    XCTAssertFalse(DitoIdentifyOffline.shared.getSavingState)
    XCTAssertNil(DitoTrackOffline().reference)
    XCTAssertNil(DitoNotificationOffline().reference)
    assertFacadeStaticState(
      appKey: appKey,
      appSecret: (appSecret.data(using: .utf8) ?? Data()).base64EncodedString(),
      signature: appSecret.sha1,
      apiKey: "",
      bundleId: ""
    )
    XCTAssertTrue(Dito.shared.getNotifications().contains { $0.notificationId == notificationId })

    DitoIdentifyOffline.shared.finishIdentify()
    XCTAssertEqual(callbackCallCount, 0)
  }

  #if DEBUG
  func testIdentify_viaDitoStaticAPI_mockIngestReceivesIdentifyActivity() async throws {
    let mock = MockMobileIngestClient()
    Dito.testIdentifyTrackIngestClient = mock
    addTeardownBlock {
      Dito.testIdentifyTrackIngestClient = nil
    }

    let appKey = "facade-ingest-app-key"
    let appSecret = "facade-ingest-secret"
    Dito.configure(appKey: appKey, appSecret: appSecret)

    let userId = "facade-user-identify-1"
    Dito.identify(id: userId, name: "Facade", email: "facade@example.com", customData: nil)

    await waitForActivityCalls(mock, count: 1)
    let req = try XCTUnwrap(mock.lastActivityRequest)
    XCTAssertEqual(req.userID, userId)
    XCTAssertEqual(req.activities.count, 1)
    let activity = req.activities[0]
    XCTAssertEqual(activity.type, .activityIdentify)
    switch activity.activity {
    case .identify(let info)?:
      XCTAssertEqual(info.email, "facade@example.com")
    default:
      XCTFail("esperado activity identify, obtido \(String(describing: activity.activity))")
    }
  }

  func testIdentifyThenTrack_viaDitoStaticAPI_mockIngestReceivesIdentifyThenTrackInOrder() async throws {
    let mock = MockMobileIngestClient()
    Dito.testIdentifyTrackIngestClient = mock
    addTeardownBlock {
      Dito.testIdentifyTrackIngestClient = nil
    }

    Dito.configure(appKey: "facade-seq-app-key", appSecret: "facade-seq-secret")

    let userId = "facade-user-seq-1"
    Dito.identify(id: userId, email: "seq@example.com")
    await waitForActivityCalls(mock, count: 1)

    let first = try XCTUnwrap(mock.allActivityRequests.first)
    XCTAssertEqual(first.userID, userId)
    XCTAssertEqual(first.activities.count, 1)
    XCTAssertEqual(first.activities[0].type, .activityIdentify)

    Dito.track(action: "facade_controlled_track", data: ["source": "facade_test"])
    await waitForActivityCalls(mock, count: 2)

    let second = try XCTUnwrap(mock.allActivityRequests.last)
    XCTAssertEqual(second.userID, userId)
    XCTAssertEqual(second.activities.count, 1)
    XCTAssertEqual(second.activities[0].type, .activityTrack)
    switch second.activities[0].activity {
    case .track(let track)?:
      XCTAssertEqual(track.event, "facade_controlled_track")
    default:
      XCTFail("esperado activity track, obtido \(String(describing: second.activities[0].activity))")
    }
  }

  func testRegisterDevice_withoutPriorIdentify_sendsAnonymousTokenRegisterAndDoesNotPersistOffline() async throws {
    let mock = MockMobileIngestClient()
    DitoNotification.testMobileIngestClient = mock
    addTeardownBlock { DitoNotification.testMobileIngestClient = nil }
    DeviceIdProvider.setForTests("facade-anon-register-device")
    Dito.configure(appKey: "facade-token-anon-reg-key", appSecret: "facade-token-anon-reg-secret")

    let token = "fcm-anon-register-token-facade-1"
    let status = await withCheckedContinuation { (cont: CheckedContinuation<DitoOperationStatus?, Never>) in
      Dito.registerDevice(token: token) { cont.resume(returning: try? $0.get()) }
    }

    XCTAssertEqual(status, .sent)
    XCTAssertEqual(mock.activityCallCount, 1)
    let req = try XCTUnwrap(mock.lastActivityRequest)
    XCTAssertEqual(req.userID, "")
    XCTAssertEqual(req.device.deviceID, "facade-anon-register-device")
    let activity = try XCTUnwrap(req.activities.last)
    switch activity.activity {
    case .tokenRegister(let info)?:
      XCTAssertEqual(info.token, token)
    default:
      XCTFail("esperado tokenRegister, obtido \(String(describing: activity.activity))")
    }
    XCTAssertNil(DitoNotificationRegisterDataManager().fetch)
  }

  func testUnregisterDevice_withoutPriorIdentify_sendsAnonymousTokenUnregisterAndDoesNotPersistOffline() async throws {
    let mock = MockMobileIngestClient()
    DitoNotification.testMobileIngestClient = mock
    addTeardownBlock { DitoNotification.testMobileIngestClient = nil }
    DeviceIdProvider.setForTests("facade-anon-unregister-device")
    Dito.configure(appKey: "facade-token-anon-unreg-key", appSecret: "facade-token-anon-unreg-secret")

    let token = "fcm-anon-unregister-token-facade-1"
    let status = await withCheckedContinuation { (cont: CheckedContinuation<DitoOperationStatus?, Never>) in
      Dito.unregisterDevice(token: token) { cont.resume(returning: try? $0.get()) }
    }

    XCTAssertEqual(status, .sent)
    XCTAssertEqual(mock.activityCallCount, 1)
    let req = try XCTUnwrap(mock.lastActivityRequest)
    XCTAssertEqual(req.userID, "")
    let activity = try XCTUnwrap(req.activities.last)
    switch activity.activity {
    case .tokenUnregister(let info)?:
      XCTAssertEqual(info.token, token)
    default:
      XCTFail("esperado tokenUnregister, obtido \(String(describing: activity.activity))")
    }
    XCTAssertNil(DitoNotificationUnregisterDataManager().fetch)
  }

  func testAfterLogout_trackAndTokenAreSentAnonymously() async throws {
    let mock = MockMobileIngestClient()
    Dito.testIdentifyTrackIngestClient = mock
    DitoNotification.testMobileIngestClient = mock
    addTeardownBlock {
      Dito.testIdentifyTrackIngestClient = nil
      DitoNotification.testMobileIngestClient = nil
    }
    DeviceIdProvider.setForTests("facade-after-logout-device")
    Dito.configure(appKey: "facade-after-logout-key", appSecret: "facade-after-logout-secret")
    let userId = "facade-user-after-logout"
    XCTAssertTrue(DitoIdentifyDataManager.shared.save(id: userId, reference: userId, json: nil, send: true))

    Dito.logout()
    let trackStatus = await withCheckedContinuation { (cont: CheckedContinuation<DitoOperationStatus?, Never>) in
      Dito.track(action: "after_logout_evt") { cont.resume(returning: try? $0.get()) }
    }
    let tokenStatus = await withCheckedContinuation { (cont: CheckedContinuation<DitoOperationStatus?, Never>) in
      Dito.registerDevice(token: "fcm-after-logout") { cont.resume(returning: try? $0.get()) }
    }

    XCTAssertEqual(trackStatus, .sent)
    XCTAssertEqual(tokenStatus, .sent)
    XCTAssertEqual(mock.activityCallCount, 2)
    XCTAssertTrue(mock.allActivityRequests.allSatisfy { $0.userID.isEmpty })
  }

  func testIdentifySuccess_resendsLastRegisteredTokenWithUser() async throws {
    let mock = MockMobileIngestClient()
    Dito.testIdentifyTrackIngestClient = mock
    DitoNotification.testMobileIngestClient = mock
    addTeardownBlock {
      Dito.testIdentifyTrackIngestClient = nil
      DitoNotification.testMobileIngestClient = nil
    }
    DeviceIdProvider.setForTests("facade-token-resend-device")
    Dito.configure(appKey: "facade-token-resend-key", appSecret: "facade-token-resend-secret")

    let token = "fcm-token-resend-facade-1"
    Dito.registerDevice(token: token)
    await waitForActivityCalls(mock, count: 1)
    XCTAssertEqual(mock.lastActivityRequest?.userID, "")

    let userId = "facade-user-token-resend-1"
    Dito.identify(id: userId, email: "resend@example.com")
    await waitUntil { !self.tokenRegisterRequests(mock, userId: userId, token: token).isEmpty }

    XCTAssertEqual(tokenRegisterRequests(mock, userId: userId, token: token).count, 1)
  }

  func testIdentifySuccess_afterUnregister_doesNotResendToken() async throws {
    let mock = MockMobileIngestClient()
    Dito.testIdentifyTrackIngestClient = mock
    DitoNotification.testMobileIngestClient = mock
    addTeardownBlock {
      Dito.testIdentifyTrackIngestClient = nil
      DitoNotification.testMobileIngestClient = nil
    }
    DeviceIdProvider.setForTests("facade-token-no-resend-device")
    Dito.configure(appKey: "facade-token-no-resend-key", appSecret: "facade-token-no-resend-secret")

    let token = "fcm-token-no-resend-facade-1"
    Dito.registerDevice(token: token)
    await waitForActivityCalls(mock, count: 1)
    Dito.unregisterDevice(token: token)
    await waitForActivityCalls(mock, count: 2)
    XCTAssertNil(UserDefaults.lastPushToken)

    let userId = "facade-user-token-no-resend-1"
    Dito.identify(id: userId, email: "noresend@example.com")
    await waitUntil { (DitoNotificationOffline().reference ?? "") == userId }
    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertTrue(tokenRegisterRequests(mock, userId: userId, token: token).isEmpty)
  }

  func testRegisterDevice_afterIdentify_mockIngestReceivesTokenRegisterAndDoesNotPersistOffline() async throws {
    let mock = MockMobileIngestClient()
    Dito.testIdentifyTrackIngestClient = mock
    DitoNotification.testMobileIngestClient = mock
    addTeardownBlock {
      Dito.testIdentifyTrackIngestClient = nil
      DitoNotification.testMobileIngestClient = nil
    }

    Dito.configure(appKey: "facade-token-online-reg-key", appSecret: "facade-token-online-reg-secret")

    let userId = "facade-user-token-reg-1"
    let token = "fcm-online-register-token-facade-1"
    Dito.identify(id: userId, email: "tokenreg@example.com")
    await waitForActivityCalls(mock, count: 1)
    await waitUntil { (DitoNotificationOffline().reference ?? "") == userId }

    Dito.registerDevice(token: token)
    await waitForActivityCalls(mock, count: 2)

    XCTAssertNil(DitoNotificationRegisterDataManager().fetch, "sucesso online não deve deixar registo pendente em UserDefaults")

    let tokenReq = try XCTUnwrap(mock.allActivityRequests.last)
    XCTAssertEqual(tokenReq.userID, userId)
    XCTAssertEqual(tokenReq.activities.count, 1)
    let activity = tokenReq.activities[0]
    XCTAssertEqual(activity.type, .activityRegister)
    switch activity.activity {
    case .tokenRegister(let info)?:
      XCTAssertEqual(info.token, token)
    default:
      XCTFail("esperado tokenRegister, obtido \(String(describing: activity.activity))")
    }
  }

  func testUnregisterDevice_afterIdentify_mockIngestReceivesTokenUnregisterAndDoesNotPersistOffline() async throws {
    let mock = MockMobileIngestClient()
    Dito.testIdentifyTrackIngestClient = mock
    DitoNotification.testMobileIngestClient = mock
    addTeardownBlock {
      Dito.testIdentifyTrackIngestClient = nil
      DitoNotification.testMobileIngestClient = nil
    }

    Dito.configure(appKey: "facade-token-online-unreg-key", appSecret: "facade-token-online-unreg-secret")

    let userId = "facade-user-token-unreg-1"
    let token = "fcm-online-unregister-token-facade-1"
    Dito.identify(id: userId, email: "tokenunreg@example.com")
    await waitForActivityCalls(mock, count: 1)
    await waitUntil { (DitoNotificationOffline().reference ?? "") == userId }

    Dito.unregisterDevice(token: token)
    await waitForActivityCalls(mock, count: 2)

    XCTAssertNil(DitoNotificationUnregisterDataManager().fetch, "sucesso online não deve deixar fila Core Data de unregister")

    let tokenReq = try XCTUnwrap(mock.allActivityRequests.last)
    XCTAssertEqual(tokenReq.userID, userId)
    XCTAssertEqual(tokenReq.activities.count, 1)
    let activity = tokenReq.activities[0]
    XCTAssertEqual(activity.type, .activityRegister)
    switch activity.activity {
    case .tokenUnregister(let info)?:
      XCTAssertEqual(info.token, token)
    default:
      XCTFail("esperado tokenUnregister, obtido \(String(describing: activity.activity))")
    }
  }

  private func tokenRegisterRequests(
    _ mock: MockMobileIngestClient,
    userId: String,
    token: String
  ) -> [Mobileingest_V1_Request] {
    mock.allActivityRequests.filter { req in
      req.userID == userId && req.activities.contains { activity in
        guard let oneOf = activity.activity, case .tokenRegister(let reg) = oneOf else { return false }
        return reg.token == token
      }
    }
  }

  private func waitForActivityCalls(_ mock: MockMobileIngestClient, count: Int, timeout: TimeInterval = 10) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if mock.activityCallCount >= count { return }
      try? await Task.sleep(nanoseconds: 25_000_000)
    }
    XCTFail("timeout à espera de \(count) chamada(s) a ingest; obtidas \(mock.activityCallCount)")
  }

  private func waitUntil(_ condition: @escaping () -> Bool, timeout: TimeInterval = 10) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if condition() { return }
      try? await Task.sleep(nanoseconds: 25_000_000)
    }
    XCTFail("timeout à espera da condição de persistência offline")
  }
  #endif

  private func assertFacadeStaticState(
    appKey: String,
    appSecret: String,
    signature: String,
    apiKey: String,
    bundleId: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    XCTAssertEqual(Dito.appKey, appKey, file: file, line: line)
    XCTAssertEqual(Dito.appSecret, appSecret, file: file, line: line)
    XCTAssertEqual(Dito.signature, signature, file: file, line: line)
    XCTAssertEqual(Dito.apiKey, apiKey, file: file, line: line)
    XCTAssertEqual(Dito.bundleId, bundleId, file: file, line: line)
  }
}
