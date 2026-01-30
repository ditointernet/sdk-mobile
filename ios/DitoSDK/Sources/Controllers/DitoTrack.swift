import Foundation

class DitoTrack {

  private let service: DitoTrackService
  private let trackOffline: DitoTrackOffline

  init(
    service: DitoTrackService = .init(),
    trackOffline: DitoTrackOffline = .init()
  ) {
    self.service = service
    self.trackOffline = trackOffline
  }

  func track(data: DitoEvent) {
    #if DEBUG
    DitoLogger.information("📊 [TRACK] action=\(data.action)")
    #endif

    if trackOffline.checkIdentifyState() {
      trackOffline.setTrackCompletion {
        self.completeTracking(data: data)
      }
    } else {
      DispatchQueue.main.async {
        self.completeTracking(data: data)
      }
    }
  }

  private func completeTracking(data: DitoEvent) {
    DispatchQueue.global().async {
      let eventRequest = self.createEventRequest(from: data)
      guard let reference = self.getValidReference() else {
        self.handleTrackingWithoutReference(eventRequest: eventRequest)
        return
      }
      self.performTracking(reference: reference, eventRequest: eventRequest)
    }
  }

  private func createEventRequest(from event: DitoEvent) -> DitoEventRequest {
    DitoEventRequest(
      platformAppKey: Dito.appKey,
      sha1Signature: Dito.signature,
      event: event
    )
  }

  private func getValidReference() -> String? {
    let reference = trackOffline.reference

    #if DEBUG
    if let ref = reference, !ref.isEmpty {
      DitoLogger.debug("✓ [TRACK] Reference encontrada: \(ref)")
    } else {
      DitoLogger.warning("⚠️ [TRACK] Reference não encontrada ou vazia")
    }
    #endif

    guard let reference = reference, !reference.isEmpty else {
      return nil
    }
    return reference
  }

  private func handleTrackingWithoutReference(eventRequest: DitoEventRequest) {
    trackOffline.track(event: eventRequest)
    DitoLogger.warning("⚠️ [TRACK] Usuário não identificado - salvando evento offline")
  }

  private func performTracking(reference: String, eventRequest: DitoEventRequest) {
    service.event(reference: reference, data: eventRequest) { [weak self] track, error in
      guard let self = self else { return }
      if let error = error {
        self.handleTrackingError(eventRequest: eventRequest, error: error)
      } else {
        self.handleTrackingSuccess()
      }
    }
  }

  private func handleTrackingError(eventRequest: DitoEventRequest, error: Error) {
    trackOffline.track(event: eventRequest)
    DitoLogger.error(error.localizedDescription)
  }

  private func handleTrackingSuccess() {
    DitoLogger.information("✅ [TRACK] Sucesso")
  }
}
