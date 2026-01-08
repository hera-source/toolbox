import AVFoundation
import Combine

final class CameraService {
    enum CameraError: Error {
        case authorizationDenied
        case configurationFailed
    }

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var videoDeviceInput: AVCaptureDeviceInput?

    let errorPublisher = PassthroughSubject<CameraError, Never>()

    func requestAccessAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.configureSession()
                } else {
                    self.errorPublisher.send(.authorizationDenied)
                }
            }
        default:
            errorPublisher.send(.authorizationDenied)
        }
    }

    func startSession() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            defer {
                self.session.commitConfiguration()
            }

            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                self.errorPublisher.send(.configurationFailed)
                return
            }

            do {
                let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.session.canAddInput(videoDeviceInput) {
                    self.session.addInput(videoDeviceInput)
                    self.videoDeviceInput = videoDeviceInput
                } else {
                    self.errorPublisher.send(.configurationFailed)
                    return
                }

                try self.configureStaticTripodMode(for: videoDevice)
            } catch {
                self.errorPublisher.send(.configurationFailed)
            }
        }
    }

    private func configureStaticTripodMode(for device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        if device.isFocusModeSupported(.locked) {
            device.focusMode = .locked
        }

        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }

        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }

        device.isSubjectAreaChangeMonitoringEnabled = false
    }
}
