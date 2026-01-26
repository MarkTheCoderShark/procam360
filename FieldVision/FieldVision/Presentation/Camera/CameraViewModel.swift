import SwiftUI
import UIKit
import AVFoundation
import CoreLocation
import Photos

@MainActor
final class CameraViewModel: NSObject, ObservableObject {
    @Published var isCapturing = false
    @Published var isRecording = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var captureMode: CaptureMode = .photo
    @Published var error: String?
    @Published var lastCapturedThumbnail: UIImage?
    @Published var isOnline = true
    @Published var isCameraAuthorized = false

    let session = AVCaptureSession()

    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private let locationManager = LocationManager.shared
    private var photoCaptureCompletion: ((Data?, CaptureMetadata) -> Void)?
    private var videoRecordingCompletion: ((URL?, CaptureMetadata) -> Void)?
    private var recordingStartTime: Date?
    private var isSessionConfigured = false

    override init() {
        super.init()
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            error = "Could not access camera"
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
        }

        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            self.photoOutput = photoOutput
        }

        let videoOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            self.videoOutput = videoOutput
        }

        session.commitConfiguration()
    }

    func startSession() {
        guard !session.isRunning else { return }

        // Check camera authorization first
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.setupAndStartSession()
                    } else {
                        self?.error = "Camera access is required to take photos"
                        self?.isCameraAuthorized = false
                    }
                }
            }
        case .denied, .restricted:
            error = "Camera access denied. Please enable in Settings."
            isCameraAuthorized = false
        @unknown default:
            error = "Unknown camera authorization status"
        }

        locationManager.requestLocation()
    }

    private func setupAndStartSession() {
        isCameraAuthorized = true

        if !isSessionConfigured {
            configureSession()
            isSessionConfigured = true
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopSession() {
        guard session.isRunning else { return }

        Task.detached(priority: .userInitiated) { [weak self] in
            self?.session.stopRunning()
        }
    }

    func toggleFlash() {
        flashMode = flashMode == .off ? .on : .off
    }

    func switchCamera() {
        session.beginConfiguration()

        guard let currentInput = session.inputs.first(where: { ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.video) == true }) as? AVCaptureDeviceInput else {
            session.commitConfiguration()
            return
        }

        session.removeInput(currentInput)

        currentCameraPosition = currentCameraPosition == .back ? .front : .back

        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let newInput = try? AVCaptureDeviceInput(device: newCamera) else {
            if session.canAddInput(currentInput) {
                session.addInput(currentInput)
            }
            session.commitConfiguration()
            return
        }

        if session.canAddInput(newInput) {
            session.addInput(newInput)
        }

        session.commitConfiguration()
    }

    func capturePhoto(completion: @escaping (Data?, CaptureMetadata) -> Void) {
        guard let photoOutput = photoOutput else {
            completion(nil, currentMetadata)
            return
        }

        isCapturing = true
        photoCaptureCompletion = completion

        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func startRecording() {
        guard let videoOutput = videoOutput else { return }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        recordingStartTime = Date()
        isRecording = true

        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
    }

    func stopRecording(completion: @escaping (URL?, CaptureMetadata) -> Void) {
        videoRecordingCompletion = completion
        videoOutput?.stopRecording()
    }

    private var currentMetadata: CaptureMetadata {
        let location = locationManager.currentLocation
        return CaptureMetadata(
            timestamp: Date(),
            latitude: location?.coordinate.latitude ?? 0,
            longitude: location?.coordinate.longitude ?? 0
        )
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        Task { @MainActor in
            self.isCapturing = false

            if let error = error {
                self.error = error.localizedDescription
                self.photoCaptureCompletion?(nil, self.currentMetadata)
                return
            }

            guard let imageData = photo.fileDataRepresentation() else {
                self.photoCaptureCompletion?(nil, self.currentMetadata)
                return
            }

            if let thumbnail = UIImage(data: imageData)?.preparingThumbnail(of: CGSize(width: 100, height: 100)) {
                self.lastCapturedThumbnail = thumbnail
            }

            self.photoCaptureCompletion?(imageData, self.currentMetadata)
            self.photoCaptureCompletion = nil
        }
    }
}

extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            self.isRecording = false

            if let error = error {
                self.error = error.localizedDescription
                self.videoRecordingCompletion?(nil, self.currentMetadata)
                return
            }

            self.videoRecordingCompletion?(outputFileURL, self.currentMetadata)
            self.videoRecordingCompletion = nil
        }
    }
}

final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private(set) var currentLocation: CLLocation?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        let status = manager.authorizationStatus

        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}
