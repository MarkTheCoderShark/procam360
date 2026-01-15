import SwiftUI
import AVFoundation
import Speech

struct VoiceNoteView: View {
    let photo: Photo
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = VoiceNoteViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: FVSpacing.xl) {
                Spacer()
                
                recordingIndicator
                
                if let transcription = viewModel.transcription {
                    transcriptionView(transcription)
                }
                
                Spacer()
                
                recordButton
                
                skipButton
            }
            .padding()
            .navigationTitle("Add Voice Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    private var recordingIndicator: some View {
        VStack(spacing: FVSpacing.md) {
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? FVColors.error.opacity(0.2) : FVColors.secondaryBackground)
                    .frame(width: 120, height: 120)
                
                if viewModel.isRecording {
                    Circle()
                        .stroke(FVColors.error, lineWidth: 3)
                        .frame(width: 120, height: 120)
                        .scaleEffect(viewModel.audioLevel)
                        .animation(.easeOut(duration: 0.1), value: viewModel.audioLevel)
                }
                
                Image(systemName: viewModel.isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(viewModel.isRecording ? FVColors.error : FVColors.Fallback.primary)
            }
            
            if viewModel.isRecording {
                Text(viewModel.recordingDuration)
                    .font(FVTypography.Mono.body)
                    .foregroundStyle(FVColors.error)
            } else if viewModel.isProcessing {
                HStack(spacing: FVSpacing.xs) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Processing...")
                }
                .foregroundStyle(FVColors.secondaryLabel)
            } else {
                Text("Tap and hold to record")
                    .font(FVTypography.subheadline)
                    .foregroundStyle(FVColors.secondaryLabel)
            }
        }
    }
    
    private func transcriptionView(_ transcription: String) -> some View {
        VStack(alignment: .leading, spacing: FVSpacing.sm) {
            Text("Transcription")
                .font(FVTypography.caption)
                .foregroundStyle(FVColors.secondaryLabel)
            
            Text(transcription)
                .font(FVTypography.body)
                .foregroundStyle(FVColors.label)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FVColors.secondaryBackground)
                .cornerRadius(FVRadius.md)
        }
    }
    
    private var recordButton: some View {
        Button {
            // Tap toggles recording
        } label: {
            Circle()
                .fill(viewModel.isRecording ? FVColors.error : FVColors.Fallback.primary)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.1)
                .onEnded { _ in
                    viewModel.startRecording()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    if viewModel.isRecording {
                        viewModel.stopRecording { transcription in
                            if let transcription = transcription {
                                photo.voiceNoteTranscription = transcription
                            }
                        }
                    }
                }
        )
        .disabled(viewModel.isProcessing)
    }
    
    private var skipButton: some View {
        Button {
            if viewModel.transcription != nil {
                onDismiss()
                dismiss()
            }
        } label: {
            Text(viewModel.transcription != nil ? "Save & Continue" : "Skip")
                .font(FVTypography.headline)
                .foregroundStyle(viewModel.transcription != nil ? .white : FVColors.Fallback.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FVSpacing.sm)
                .background(viewModel.transcription != nil ? FVColors.Fallback.primary : .clear)
                .cornerRadius(FVRadius.md)
        }
    }
}

@MainActor
final class VoiceNoteViewModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var audioLevel: CGFloat = 1.0
    @Published var recordingDuration = "0:00"
    @Published var transcription: String?
    @Published var error: String?
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingTimer: Timer?
    private var startTime: Date?
    private var levelTimer: Timer?
    
    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            self.error = "Could not set up audio session"
            return
        }
        
        let fileName = "\(UUID().uuidString).m4a"
        recordingURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            startTime = Date()
            
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateDuration()
                }
            }
            
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateLevel()
                }
            }
        } catch {
            self.error = "Could not start recording"
        }
    }
    
    func stopRecording(completion: @escaping (String?) -> Void) {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        isRecording = false
        
        guard let url = recordingURL else {
            completion(nil)
            return
        }
        
        isProcessing = true
        
        Task {
            let transcription = await transcribeAudio(url: url)
            self.transcription = transcription
            self.isProcessing = false
            completion(transcription)
        }
    }
    
    private func updateDuration() {
        guard let startTime = startTime else { return }
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        recordingDuration = String(format: "%d:%02d", minutes, seconds)
    }
    
    private func updateLevel() {
        audioRecorder?.updateMeters()
        let level = audioRecorder?.averagePower(forChannel: 0) ?? -160
        let normalizedLevel = max(0, (level + 50) / 50)
        audioLevel = 1.0 + CGFloat(normalizedLevel) * 0.3
    }
    
    private func transcribeAudio(url: URL) async -> String? {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            SFSpeechRecognizer.requestAuthorization { _ in }
            return nil
        }
        
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            return nil
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        do {
            let result = try await recognizer.recognitionTask(with: request)
            return result.bestTranscription.formattedString
        } catch {
            print("Transcription error: \(error)")
            return nil
        }
    }
    
    func cleanup() {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Task { @MainActor in
                self.error = "Recording failed"
            }
        }
    }
}

extension SFSpeechRecognizer {
    func recognitionTask(with request: SFSpeechRecognitionRequest) async throws -> SFSpeechRecognitionResult {
        try await withCheckedThrowingContinuation { continuation in
            recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let result = result, result.isFinal {
                    continuation.resume(returning: result)
                }
            }
        }
    }
}

#Preview {
    VoiceNoteView(photo: Photo(
        uploaderId: UUID(),
        capturedAt: Date(),
        latitude: 0,
        longitude: 0,
        localPath: ""
    )) {}
}
