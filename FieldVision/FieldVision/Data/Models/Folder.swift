import Foundation
import SwiftData

@Model
final class Folder {
    @Attribute(.unique) var id: UUID
    var name: String
    var folderType: FolderType
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus
    var remoteId: String?
    
    var project: Project?
    
    @Relationship(deleteRule: .nullify, inverse: \Photo.folder)
    var photos: [Photo] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        folderType: FolderType = .custom,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pending,
        remoteId: String? = nil,
        project: Project? = nil
    ) {
        self.id = id
        self.name = name
        self.folderType = folderType
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.remoteId = remoteId
        self.project = project
    }
}

enum FolderType: String, Codable, CaseIterable {
    case location
    case phase
    case custom
    
    var displayName: String {
        switch self {
        case .location: return "Location"
        case .phase: return "Phase"
        case .custom: return "Custom"
        }
    }
    
    var iconName: String {
        switch self {
        case .location: return "mappin.circle.fill"
        case .phase: return "clock.fill"
        case .custom: return "folder.fill"
        }
    }
    
    static var presetPhases: [String] {
        ["Before", "During", "After"]
    }
}

extension Folder {
    var photoCount: Int { photos.count }
    
    var coverPhoto: Photo? {
        photos.sorted { $0.capturedAt > $1.capturedAt }.first
    }
}
