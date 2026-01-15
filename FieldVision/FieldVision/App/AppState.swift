import SwiftUI
import Combine
import Network

/// Global app state observable across the app
@MainActor
final class AppState: ObservableObject {
    // MARK: - Network State
    @Published private(set) var isOnline: Bool = true
    @Published private(set) var syncStatus: SyncStatusType = .idle
    
    // MARK: - User State
    @Published var currentUser: User?
    
    // MARK: - UI State
    @Published var showingCamera: Bool = false
    @Published var selectedProject: Project?
    
    // MARK: - Error Handling
    @Published var globalError: AppError?
    @Published var showingError: Bool = false
    
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.fieldvision.networkmonitor")
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    func presentError(_ error: AppError) {
        globalError = error
        showingError = true
    }
    
    deinit {
        networkMonitor.cancel()
    }
}

// MARK: - Sync Status
enum SyncStatusType: Equatable {
    case idle
    case syncing(progress: Double)
    case completed
    case failed(message: String)
    
    var displayText: String {
        switch self {
        case .idle:
            return "Up to date"
        case .syncing(let progress):
            return "Syncing... \(Int(progress * 100))%"
        case .completed:
            return "Sync complete"
        case .failed(let message):
            return "Sync failed: \(message)"
        }
    }
}

// MARK: - App Error
struct AppError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let isRecoverable: Bool
    
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id
    }
    
    static func network(_ message: String) -> AppError {
        AppError(title: "Network Error", message: message, isRecoverable: true)
    }
    
    static func sync(_ message: String) -> AppError {
        AppError(title: "Sync Error", message: message, isRecoverable: true)
    }
    
    static func generic(_ message: String) -> AppError {
        AppError(title: "Error", message: message, isRecoverable: false)
    }
}
