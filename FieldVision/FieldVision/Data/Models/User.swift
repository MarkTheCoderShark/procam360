import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: UUID
    var email: String
    var name: String
    var avatarUrl: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        email: String,
        name: String,
        avatarUrl: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.avatarUrl = avatarUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension User {
    var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
