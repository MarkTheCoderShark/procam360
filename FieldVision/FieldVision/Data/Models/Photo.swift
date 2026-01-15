import Foundation
import SwiftData

@Model
final class Photo {
    @Attribute(.unique) var id: UUID
    var uploaderId: UUID
    var uploaderName: String?
    
    var capturedAt: Date
    var latitude: Double
    var longitude: Double
    
    var mediaType: MediaType
    var localPath: String
    var remoteUrl: String?
    var thumbnailLocalPath: String?
    var thumbnailRemoteUrl: String?
    
    var note: String?
    var voiceNoteLocalPath: String?
    var voiceNoteRemoteUrl: String?
    var voiceNoteTranscription: String?
    
    var syncStatus: SyncStatus
    var remoteId: String?
    var createdAt: Date
    var updatedAt: Date
    
    var project: Project?
    var folder: Folder?
    
    @Relationship(deleteRule: .cascade, inverse: \Comment.photo)
    var comments: [Comment] = []
    
    init(
        id: UUID = UUID(),
        uploaderId: UUID,
        uploaderName: String? = nil,
        capturedAt: Date = Date(),
        latitude: Double,
        longitude: Double,
        mediaType: MediaType = .photo,
        localPath: String,
        remoteUrl: String? = nil,
        thumbnailLocalPath: String? = nil,
        thumbnailRemoteUrl: String? = nil,
        note: String? = nil,
        voiceNoteLocalPath: String? = nil,
        voiceNoteRemoteUrl: String? = nil,
        voiceNoteTranscription: String? = nil,
        syncStatus: SyncStatus = .pending,
        remoteId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        project: Project? = nil,
        folder: Folder? = nil
    ) {
        self.id = id
        self.uploaderId = uploaderId
        self.uploaderName = uploaderName
        self.capturedAt = capturedAt
        self.latitude = latitude
        self.longitude = longitude
        self.mediaType = mediaType
        self.localPath = localPath
        self.remoteUrl = remoteUrl
        self.thumbnailLocalPath = thumbnailLocalPath
        self.thumbnailRemoteUrl = thumbnailRemoteUrl
        self.note = note
        self.voiceNoteLocalPath = voiceNoteLocalPath
        self.voiceNoteRemoteUrl = voiceNoteRemoteUrl
        self.voiceNoteTranscription = voiceNoteTranscription
        self.syncStatus = syncStatus
        self.remoteId = remoteId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.project = project
        self.folder = folder
    }
}

enum MediaType: String, Codable {
    case photo
    case video
    
    var iconName: String {
        switch self {
        case .photo: return "photo"
        case .video: return "video"
        }
    }
}

extension Photo {
    var hasVoiceNote: Bool {
        voiceNoteLocalPath != nil || voiceNoteRemoteUrl != nil
    }
    
    var hasNote: Bool {
        (note != nil && !note!.isEmpty) || (voiceNoteTranscription != nil && !voiceNoteTranscription!.isEmpty)
    }
    
    var displayNote: String? {
        if let note = note, !note.isEmpty {
            return note
        }
        return voiceNoteTranscription
    }
    
    var commentCount: Int { comments.count }
    
    var formattedDate: String {
        capturedAt.formatted(date: .abbreviated, time: .shortened)
    }
    
    var localURL: URL? {
        guard !localPath.isEmpty else { return nil }
        return URL(fileURLWithPath: localPath)
    }
    
    var thumbnailURL: URL? {
        if let thumbnailLocalPath = thumbnailLocalPath, !thumbnailLocalPath.isEmpty {
            return URL(fileURLWithPath: thumbnailLocalPath)
        }
        return localURL
    }
}
