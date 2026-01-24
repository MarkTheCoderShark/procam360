import Foundation

enum AppEnvironment {
    case development
    case production
    
    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    var apiBaseURL: String {
        switch self {
        case .development:
            // Use production for now (change to localhost:3000 for local dev)
            return "https://procam360-production.up.railway.app"
        case .production:
            return "https://procam360-production.up.railway.app"
        }
    }
}

enum Constants {
    // MARK: - API
    enum API {
        static var baseURL: String { AppEnvironment.current.apiBaseURL }
        static let version = "v1"
        static var fullBaseURL: String { "\(baseURL)/\(version)" }

        // Timeout intervals
        static let requestTimeout: TimeInterval = 30
        static let resourceTimeout: TimeInterval = 60
        static let uploadTimeout: TimeInterval = 300
    }

    // MARK: - Storage
    enum Storage {
        static let mediaDirectoryName = "ProCam360Media"
        static let thumbnailDirectoryName = "Thumbnails"
        static let maxThumbnailSize: CGFloat = 300
        static let jpegCompressionQuality: CGFloat = 0.8
        static let thumbnailCompressionQuality: CGFloat = 0.6
    }

    // MARK: - Sync
    enum Sync {
        static let maxRetryCount = 3
        static let retryDelayBase: TimeInterval = 2.0
        static let batchSize = 10
        static let backgroundSyncInterval: TimeInterval = 300 // 5 minutes
    }

    // MARK: - Cache
    enum Cache {
        static let maxMemoryCacheMB = 100
        static let maxDiskCacheMB = 500
        static let cacheExpirationDays = 30
    }

    // MARK: - UI
    enum UI {
        static let animationDuration: Double = 0.3
        static let cornerRadius: CGFloat = 12
        static let smallCornerRadius: CGFloat = 8
        static let gridSpacing: CGFloat = 2
        static let photoGridColumns = 3
        static let timelinePageSize = 50
    }

    // MARK: - Keychain
    enum Keychain {
        static let service = "com.procam360.app"
        static let accessTokenKey = "accessToken"
        static let refreshTokenKey = "refreshToken"
        static let userIdKey = "userId"
    }

    // MARK: - UserDefaults Keys
    enum UserDefaultsKeys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let lastSyncDate = "lastSyncDate"
        static let preferredCameraMode = "preferredCameraMode"
        static let autoVoiceNotePrompt = "autoVoiceNotePrompt"
    }

    // MARK: - Notifications
    enum NotificationNames {
        static let didCapturePhoto = Notification.Name("didCapturePhoto")
        static let syncStatusChanged = Notification.Name("syncStatusChanged")
        static let userDidLogout = Notification.Name("userDidLogout")
    }
}
