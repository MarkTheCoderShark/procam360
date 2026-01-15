import Foundation

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let name: String
}

struct AppleSignInRequest: Encodable {
    let identityToken: String
    let name: String?
    let email: String?
}

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: UserDTO
}

struct UserDTO: Codable {
    let id: UUID
    let email: String
    let name: String
    let avatarUrl: String?
    let createdAt: Date
}

struct RegisterDeviceRequest: Encodable {
    let token: String
    let platform: String
}

struct EmptyResponse: Decodable {}

struct NotificationPreferencesDTO: Codable {
    var newPhotos: Bool
    var newComments: Bool
    var projectInvites: Bool
    var syncComplete: Bool
}

struct ChangePasswordRequest: Encodable {
    let currentPassword: String
    let newPassword: String
}

struct ChangePasswordResponse: Decodable {
    let success: Bool
    let message: String
    let accessToken: String
    let refreshToken: String
}

struct DeleteAccountResponse: Decodable {
    let success: Bool
    let message: String
}
