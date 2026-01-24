import SwiftUI
import AVFoundation
import CoreLocation

struct CameraView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var viewModel: CameraViewModel
    @StateObject private var purchaseService = PurchaseService.shared
    @State private var showingVoiceNote = false
    @State private var capturedPhoto: Photo?
    @State private var showingPhotoDetail = false
    @State private var lastCapturedPhoto: Photo?
    @State private var showingPaywall = false
    @State private var showingPhotoLimitAlert = false
    
    private let freePhotoLimit = 100
    
    init(project: Project) {
        self.project = project
        _viewModel = StateObject(wrappedValue: CameraViewModel())
    }
    
    private var isAtPhotoLimit: Bool {
        !purchaseService.isPro && project.photos.count >= freePhotoLimit
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                CameraPreviewView(session: viewModel.session)
                    .ignoresSafeArea()
                
                VStack {
                    topBar
                    
                    Spacer()
                    
                    bottomControls(geometry: geometry)
                }
                
                if viewModel.isCapturing {
                    Color.white
                        .ignoresSafeArea()
                        .opacity(0.3)
                        .animation(.easeOut(duration: 0.1), value: viewModel.isCapturing)
                }
            }
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .sheet(isPresented: $showingVoiceNote) {
            if let photo = capturedPhoto {
                VoiceNoteView(photo: photo) {
                    capturedPhoto = nil
                }
            }
        }
        .alert("Camera Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error ?? "")
        }
        .alert("Photo Limit Reached", isPresented: $showingPhotoLimitAlert) {
            Button("Upgrade to Pro") {
                showingPaywall = true
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Free accounts are limited to \(freePhotoLimit) photos per project. Upgrade to Pro for unlimited photos.")
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
    
    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            if !viewModel.isOnline {
                HStack(spacing: FVSpacing.xxs) {
                    Image(systemName: "wifi.slash")
                    Text("Offline")
                }
                .font(FVTypography.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, FVSpacing.sm)
                .padding(.vertical, FVSpacing.xxs)
                .background(.ultraThinMaterial)
                .cornerRadius(FVRadius.full)
            }
            
            Spacer()
            
            Button {
                viewModel.toggleFlash()
            } label: {
                Image(systemName: viewModel.flashMode == .on ? "bolt.fill" : "bolt.slash")
                    .font(.title2)
                    .foregroundStyle(viewModel.flashMode == .on ? .yellow : .white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal)
        .padding(.top, FVSpacing.sm)
    }
    
    private func bottomControls(geometry: GeometryProxy) -> some View {
        VStack(spacing: FVSpacing.lg) {
            Picker("Mode", selection: $viewModel.captureMode) {
                Text("Photo").tag(CaptureMode.photo)
                Text("Video").tag(CaptureMode.video)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            
            HStack(spacing: FVSpacing.xxl) {
                if let lastThumbnail = viewModel.lastCapturedThumbnail, let photo = lastCapturedPhoto {
                    Button {
                        showingPhotoDetail = true
                    } label: {
                        Image(uiImage: lastThumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: FVRadius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: FVRadius.sm)
                                    .stroke(.white.opacity(0.5), lineWidth: 2)
                            )
                    }
                    .sheet(isPresented: $showingPhotoDetail) {
                        PhotoDetailView(photo: photo, project: project)
                    }
                } else {
                    Color.clear.frame(width: 50, height: 50)
                }
                
                captureButton
                
                Button {
                    viewModel.switchCamera()
                } label: {
                    Image(systemName: "camera.rotate")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.bottom, geometry.safeAreaInsets.bottom + FVSpacing.lg)
    }
    
    private var captureButton: some View {
        Button {
            captureMedia()
        } label: {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                
                Circle()
                    .fill(viewModel.captureMode == .video && viewModel.isRecording ? .red : .white)
                    .frame(width: viewModel.captureMode == .video && viewModel.isRecording ? 32 : 60, height: viewModel.captureMode == .video && viewModel.isRecording ? 32 : 60)
                    .cornerRadius(viewModel.captureMode == .video && viewModel.isRecording ? 8 : 30)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
            }
        }
        .disabled(viewModel.isCapturing)
    }
    
    private func captureMedia() {
        if isAtPhotoLimit {
            showingPhotoLimitAlert = true
            return
        }
        
        if viewModel.captureMode == .photo {
            viewModel.capturePhoto { imageData, metadata in
                guard let imageData = imageData else { return }
                
                let photo = savePhoto(imageData: imageData, metadata: metadata)
                capturedPhoto = photo
                lastCapturedPhoto = photo
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingVoiceNote = true
                }
            }
        } else {
            if viewModel.isRecording {
                viewModel.stopRecording { videoURL, metadata in
                    guard let videoURL = videoURL else { return }
                    saveVideo(videoURL: videoURL, metadata: metadata)
                }
            } else {
                viewModel.startRecording()
            }
        }
    }
    
    private func savePhoto(imageData: Data, metadata: CaptureMetadata) -> Photo {
        let fileName = "\(UUID().uuidString).jpg"
        let localPath = MediaStorage.shared.saveImage(imageData, fileName: fileName)
        let thumbnailPath = MediaStorage.shared.saveThumbnail(imageData, fileName: "thumb_\(fileName)")
        
        let photo = Photo(
            uploaderId: KeychainService.shared.getUserId() ?? UUID(),
            capturedAt: metadata.timestamp,
            latitude: metadata.latitude,
            longitude: metadata.longitude,
            mediaType: .photo,
            localPath: localPath,
            thumbnailLocalPath: thumbnailPath,
            project: project
        )
        
        modelContext.insert(photo)
        return photo
    }
    
    private func saveVideo(videoURL: URL, metadata: CaptureMetadata) {
        let fileName = "\(UUID().uuidString).mov"
        let localPath = MediaStorage.shared.saveVideo(from: videoURL, fileName: fileName)
        
        let photo = Photo(
            uploaderId: KeychainService.shared.getUserId() ?? UUID(),
            capturedAt: metadata.timestamp,
            latitude: metadata.latitude,
            longitude: metadata.longitude,
            mediaType: .video,
            localPath: localPath,
            project: project
        )
        
        modelContext.insert(photo)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

struct CaptureMetadata {
    let timestamp: Date
    let latitude: Double
    let longitude: Double
}

enum CaptureMode {
    case photo
    case video
}

#Preview {
    CameraView(project: Project(name: "Test", address: "123 Main St"))
}
