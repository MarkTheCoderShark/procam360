import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var address: String
    var latitude: Double?
    var longitude: Double?
    var clientName: String?
    var status: ProjectStatus
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus
    var remoteId: String?
    
    @Relationship(deleteRule: .cascade, inverse: \Folder.project)
    var folders: [Folder] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Photo.project)
    var photos: [Photo] = []
    
    @Relationship(deleteRule: .cascade, inverse: \ProjectShareLink.project)
    var shareLinks: [ProjectShareLink] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        address: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        clientName: String? = nil,
        status: ProjectStatus = .walkthrough,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pending,
        remoteId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.clientName = clientName
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.remoteId = remoteId
    }
}

enum ProjectStatus: String, Codable, CaseIterable {
    case walkthrough = "Walkthrough"
    case inProgress = "In Progress"
    case completed = "Completed"
    
    var displayName: String { rawValue }
    
    var iconName: String {
        switch self {
        case .walkthrough: return "figure.walk"
        case .inProgress: return "hammer.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

enum SyncStatus: String, Codable {
    case pending
    case syncing
    case synced
    case failed
    
    var isPending: Bool {
        self == .pending || self == .failed
    }
}

extension Project {
    var photoCount: Int { photos.count }
    var folderCount: Int { folders.count }
    
    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }
    
    var statusColor: String {
        switch status {
        case .walkthrough: return "blue"
        case .inProgress: return "orange"
        case .completed: return "green"
        }
    }
}
