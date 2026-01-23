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
    let resolvedSignature = sha1Signature ?? Dito.signature
    let apiKey = Dito.apiKey
    identifyOffline.initiateIdentify()
    let signupRequest = createSignupRequest(
      apiKey: apiKey,
      signature: resolvedSignature,
      userData: data
    )
    guard hasValidEmail(data) else {
      identifyOffline.finishIdentify()
      return
    }
    performSignup(id: id, signupRequest: signupRequest)
  }

  private func createSignupRequest(
    apiKey: String,
    signature: String,
    userData: DitoUser?
  ) -> DitoSignupRequest {
    DitoSignupRequest(
      platformApiKey: apiKey,
      sha1Signature: signature,
      userData: userData
    )
  }

  private func hasValidEmail(_ userData: DitoUser?) -> Bool {
    userData?.email != nil
  }

  private func performSignup(id: String, signupRequest: DitoSignupRequest) {
    service.signup(network: "portal", id: id, data: signupRequest) {
      [weak self] identify, error in
      guard let self = self else { return }
      if let error = error {
        self.handleSignupError(id: id, signupRequest: signupRequest, error: error)
      } else {
        self.handleSignupSuccess(id: id, signupRequest: signupRequest, identify: identify)
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
      identifyOffline.identify(
        id: id,
        params: signupRequest,
        reference: nil,
        send: false
      )
      return
    }
    identifyOffline.identify(
      id: id,
      params: signupRequest,
      reference: reference,
      send: true
    )
    DitoLogger.information("Identify realizado")
    retry.loadOffline()
  }
}
