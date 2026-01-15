import Foundation

struct ProjectDTO: Codable {
    let id: String
    let name: String
    let address: String
    let latitude: Double?
    let longitude: Double?
    let clientName: String?
    let status: String
    let photoCount: Int?
    let folderCount: Int?
    let createdAt: Date
    let updatedAt: Date
    let folders: [FolderDTO]?
}

struct CreateProjectRequest: Encodable {
    let name: String
    let address: String
    let latitude: Double?
    let longitude: Double?
    let clientName: String?
    let status: String
}

struct UpdateProjectRequest: Encodable {
    let name: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let clientName: String?
    let status: String?
}

struct FolderDTO: Codable {
    let id: String
    let name: String
    let folderType: String
    let sortOrder: Int
    let photoCount: Int?
    let createdAt: Date
    let updatedAt: Date
}

struct CreateFolderRequest: Encodable {
    let name: String
    let folderType: String
}

struct PhotoDTO: Codable {
    let id: String
    let uploaderId: String
    let uploaderName: String?
    let capturedAt: Date
    let latitude: Double
    let longitude: Double
    let mediaType: String
    let remoteUrl: String
    let thumbnailUrl: String?
    let note: String?
    let voiceNoteUrl: String?
    let voiceNoteTranscription: String?
    let folderId: String?
    let commentCount: Int?
    let createdAt: Date
    let updatedAt: Date
}

struct CreatePhotoRequest: Encodable {
    let projectId: String
    let folderId: String?
    let capturedAt: Date
    let latitude: Double
    let longitude: Double
    let mediaType: String
    let remoteUrl: String
    let thumbnailUrl: String?
    let note: String?
}

struct UploadUrlResponse: Decodable {
    let uploadUrl: String
    let mediaUrl: String
    let thumbnailUploadUrl: String?
    let thumbnailUrl: String?
}

struct CommentDTO: Codable {
    let id: String
    let userId: String
    let userName: String
    let userAvatarUrl: String?
    let text: String
    let createdAt: Date
}

struct ShareLinkDTO: Codable {
    let id: String
    let token: String
    let shareUrl: String
    let folderIds: [String]
    let dateRangeStart: Date?
    let dateRangeEnd: Date?
    let expiresAt: Date?
    let passwordProtected: Bool
    let allowDownload: Bool
    let allowComments: Bool
    let isActive: Bool
    let createdAt: Date
}

struct CreateShareLinkRequest: Encodable {
    let folderIds: [String]?
    let dateRangeStart: Date?
    let dateRangeEnd: Date?
    let expiresAt: Date?
    let password: String?
    let allowDownload: Bool
    let allowComments: Bool
}

struct TranscriptionResponse: Decodable {
    let transcription: String
    let voiceNoteUrl: String
}

struct PaginatedResponse<T: Decodable>: Decodable {
    let data: [T]
    let page: Int
    let limit: Int
    let total: Int
    let hasMore: Bool
}

struct SearchResponse: Decodable {
    let projects: [SearchProjectResult]
    let photos: [SearchPhotoResult]
    let query: String
    let page: Int
    let limit: Int
    let totalProjects: Int
    let totalPhotos: Int
    let hasMoreProjects: Bool
    let hasMorePhotos: Bool
}

struct SearchProjectResult: Decodable, Identifiable {
    let id: String
    let name: String
    let address: String
    let clientName: String?
    let status: String
    let photoCount: Int
    let folderCount: Int
    let updatedAt: Date
}

struct SearchPhotoResult: Decodable, Identifiable {
    let id: String
    let projectId: String
    let projectName: String
    let uploaderName: String
    let capturedAt: Date
    let mediaType: String
    let thumbnailUrl: String?
    let note: String?
    let voiceNoteTranscription: String?
    let commentCount: Int
}
