import AVFoundation
import Combine
import SwiftUI

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var errorMessage: String?

    let cameraService = CameraService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        cameraService.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                switch error {
                case .authorizationDenied:
                    self?.errorMessage = "Kamerazugriff verweigert. Bitte in den Einstellungen erlauben."
                case .configurationFailed:
                    self?.errorMessage = "Kamera konnte nicht initialisiert werden."
                }
            }
            .store(in: &cancellables)
    }

    func onAppear() {
        cameraService.requestAccessAndConfigure()
        cameraService.startSession()
    }

    func onDisappear() {
        cameraService.stopSession()
    }
}
