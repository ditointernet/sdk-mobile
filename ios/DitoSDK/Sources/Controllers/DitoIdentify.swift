import Foundation

class DitoIdentify {

  private let service: DitoIdentifyService
  private let identifyOffline: DitoIdentifyOffline
  private let retry: DitoRetry

  init(
    service: DitoIdentifyService = .init(),
    identifyOffline: DitoIdentifyOffline = .shared,
    retry: DitoRetry = .init()
  ) {
    self.service = service
    self.identifyOffline = identifyOffline
    self.retry = retry
  }

  func identify(
    id: String,
    data: DitoUser? = nil,
    sha1Signature: String? = nil
  ) {
    #if DEBUG
    DitoLogger.information("🆔 [IDENTIFY] user_id=\(id), email=\(data?.email ?? "nil")")
    #endif

    let resolvedSignature = sha1Signature ?? Dito.signature
    let appKey = Dito.appKey
    identifyOffline.initiateIdentify()
    let signupRequest = createSignupRequest(
      appKey: appKey,
      signature: resolvedSignature,
      userData: data
    )
    guard hasValidId(id) else {
      identifyOffline.finishIdentify()
      return
    }
    performSignup(id: id, signupRequest: signupRequest)
  }

  private func createSignupRequest(
    appKey: String,
    signature: String,
    userData: DitoUser?
  ) -> DitoSignupRequest {
    DitoSignupRequest(
      platformAppKey: appKey,
      sha1Signature: signature,
      userData: userData
    )
  }

  private func hasValidId(_ id: String) -> Bool {
    !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func performSignup(id: String, signupRequest: DitoSignupRequest) {
    service.signup(network: "portal", id: id, data: signupRequest) {
      identify, error in
      if let error = error {
        self.handleSignupError(id: id, signupRequest: signupRequest, error: error)
      } else {
        self.handleSignupSuccess(
          id: id,
          signupRequest: signupRequest,
          identify: identify
        )
      }
      self.identifyOffline.finishIdentify()
    }
  }

  private func handleSignupError(
    id: String,
    signupRequest: DitoSignupRequest,
    error: Error
  ) {
    identifyOffline.identify(
      id: id,
      params: signupRequest,
      reference: nil,
      send: false
    )
    DitoLogger.error(error.localizedDescription)
  }

  private func handleSignupSuccess(
    id: String,
    signupRequest: DitoSignupRequest,
    identify: DitoIdentifyModel?
  ) {
    guard let reference = identify?.reference else {
      #if DEBUG
      DitoLogger.warning("⚠️ [IDENTIFY] Response sem reference - salvando offline")
      #endif
      identifyOffline.identify(
        id: id,
        params: signupRequest,
        reference: nil,
        send: false
      )
      return
    }

    #if DEBUG
    DitoLogger.debug("💾 [IDENTIFY] Salvando reference=\(reference)")
    #endif

    identifyOffline.identify(
      id: id,
      params: signupRequest,
      reference: reference,
      send: true
    )

    #if DEBUG
    DitoLogger.information("✅ [IDENTIFY] Sucesso - reference salva")
    #endif

    retry.loadOffline()
  }
}
