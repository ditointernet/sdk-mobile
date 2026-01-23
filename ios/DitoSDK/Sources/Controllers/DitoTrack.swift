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
      let eventRequest = createEventRequest(from: data)
      guard let reference = getValidReference() else {
        handleTrackingWithoutReference(eventRequest: eventRequest)
        return
      }
      performTracking(reference: reference, eventRequest: eventRequest)
    }
  }

  private func createEventRequest(from event: DitoEvent) -> DitoEventRequest {
    DitoEventRequest(
      platformApiKey: Dito.apiKey,
      sha1Signature: Dito.signature,
      event: event
    )
  }

  private func getValidReference() -> String? {
    guard let reference = trackOffline.reference, !reference.isEmpty else {
      return nil
    }
    return reference
  }

  private func handleTrackingWithoutReference(eventRequest: DitoEventRequest) {
    trackOffline.track(event: eventRequest)
    DitoLogger.warning("Track - Antes de enviar um evento é preciso identificar o usuário.")
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
    DitoLogger.information("Track - Evento enviado")
  }
}
