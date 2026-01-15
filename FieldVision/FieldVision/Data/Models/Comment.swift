import Foundation
import SwiftData

@Model
final class Comment {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var userName: String
    var userAvatarUrl: String?
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus
    var remoteId: String?
    
    var photo: Photo?
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        userName: String,
        userAvatarUrl: String? = nil,
        text: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pending,
        remoteId: String? = nil,
        photo: Photo? = nil
    ) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.userAvatarUrl = userAvatarUrl
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.remoteId = remoteId
        self.photo = photo
    }
}

extension Comment {
    var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(createdAt) {
            return createdAt.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(createdAt) {
            return "Yesterday"
        } else {
            return createdAt.formatted(date: .abbreviated, time: .omitted)
        }
    }
    
    var userInitials: String {
        let components = userName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(userName.prefix(2)).uppercased()
    }
}
