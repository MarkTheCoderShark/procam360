import Foundation
import SwiftData

@Model
final class SyncQueueItem {
    @Attribute(.unique) var id: UUID
    var entityType: SyncEntityType
    var entityId: UUID
    var operation: SyncOperation
    var priority: SyncPriority
    var retryCount: Int
    var lastAttemptAt: Date?
    var errorMessage: String?
    var payload: Data?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        entityType: SyncEntityType,
        entityId: UUID,
        operation: SyncOperation,
        priority: SyncPriority = .normal,
        retryCount: Int = 0,
        lastAttemptAt: Date? = nil,
        errorMessage: String? = nil,
        payload: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation
        self.priority = priority
        self.retryCount = retryCount
        self.lastAttemptAt = lastAttemptAt
        self.errorMessage = errorMessage
        self.payload = payload
        self.createdAt = createdAt
    }
}

enum SyncEntityType: String, Codable {
    case project
    case folder
    case photo
    case comment
    case shareLink
}

enum SyncOperation: String, Codable {
    case create
    case update
    case delete
}

enum SyncPriority: Int, Codable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
    
    static func < (lhs: SyncPriority, rhs: SyncPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension SyncQueueItem {
    var canRetry: Bool {
        retryCount < Constants.Sync.maxRetryCount
    }
    
    var retryDelay: TimeInterval {
        let delay = Constants.Sync.retryDelayBase * pow(2, Double(retryCount))
        return min(delay, 60)
    }
}
