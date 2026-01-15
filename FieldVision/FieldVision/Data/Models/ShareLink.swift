import Foundation
import SwiftData

@Model
final class ProjectShareLink {
    @Attribute(.unique) var id: UUID
    var token: String
    var folderIds: [UUID]
    var dateRangeStart: Date?
    var dateRangeEnd: Date?
    var expiresAt: Date?
    var passwordProtected: Bool
    var allowDownload: Bool
    var allowComments: Bool
    var isActive: Bool
    var createdById: UUID
    var createdByName: String?
    var createdAt: Date
    var accessCount: Int
    var lastAccessedAt: Date?
    var syncStatus: SyncStatus
    var remoteId: String?
    
    var project: Project?
    
    init(
        id: UUID = UUID(),
        token: String = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
        folderIds: [UUID] = [],
        dateRangeStart: Date? = nil,
        dateRangeEnd: Date? = nil,
        expiresAt: Date? = nil,
        passwordProtected: Bool = false,
        allowDownload: Bool = false,
        allowComments: Bool = false,
        isActive: Bool = true,
        createdById: UUID,
        createdByName: String? = nil,
        createdAt: Date = Date(),
        accessCount: Int = 0,
        lastAccessedAt: Date? = nil,
        syncStatus: SyncStatus = .pending,
        remoteId: String? = nil,
        project: Project? = nil
    ) {
        self.id = id
        self.token = token
        self.folderIds = folderIds
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.expiresAt = expiresAt
        self.passwordProtected = passwordProtected
        self.allowDownload = allowDownload
        self.allowComments = allowComments
        self.isActive = isActive
        self.createdById = createdById
        self.createdByName = createdByName
        self.createdAt = createdAt
        self.accessCount = accessCount
        self.lastAccessedAt = lastAccessedAt
        self.syncStatus = syncStatus
        self.remoteId = remoteId
        self.project = project
    }
}

extension ProjectShareLink {
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt < Date()
    }
    
    var isValid: Bool {
        isActive && !isExpired
    }
    
    var shareURL: URL? {
        URL(string: "\(Constants.API.baseURL)/share/\(token)")
    }
    
    var scopeDescription: String {
        if folderIds.isEmpty {
            return "Entire project"
        }
        return "\(folderIds.count) folder(s)"
    }
    
    var expirationDescription: String {
        guard let expiresAt = expiresAt else {
            return "Never expires"
        }
        if isExpired {
            return "Expired"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Expires \(formatter.localizedString(for: expiresAt, relativeTo: Date()))"
    }
}
