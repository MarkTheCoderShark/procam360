import Foundation

final class APIClient {
    static let shared = APIClient()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let keychainService = KeychainService.shared
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.API.requestTimeout
        config.timeoutIntervalForResource = Constants.API.resourceTimeout
        session = URLSession(configuration: config)
        
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }
    
    func login(email: String, password: String) async throws -> AuthResponse {
        let body = LoginRequest(email: email, password: password)
        return try await post("/auth/login", body: body)
    }
    
    func register(email: String, password: String, name: String) async throws -> AuthResponse {
        let body = RegisterRequest(email: email, password: password, name: name)
        return try await post("/auth/register", body: body)
    }
    
    func appleSignIn(identityToken: String, name: String?, email: String?) async throws -> AuthResponse {
        let body = AppleSignInRequest(identityToken: identityToken, name: name, email: email)
        return try await post("/auth/apple", body: body)
    }
    
    func getCurrentUser() async throws -> UserDTO {
        try await get("/auth/me")
    }
    
    func updateProfile(name: String?, email: String?) async throws -> UserDTO {
        var body: [String: String] = [:]
        if let name = name { body["name"] = name }
        if let email = email { body["email"] = email }
        return try await patch("/auth/me", body: body)
    }
    
    func changePassword(currentPassword: String, newPassword: String) async throws -> ChangePasswordResponse {
        let body = ChangePasswordRequest(currentPassword: currentPassword, newPassword: newPassword)
        return try await patch("/auth/password", body: body)
    }
    
    func deleteAccount() async throws {
        try await delete("/auth/account")
    }
    
    func search(query: String, type: String = "all", projectId: String? = nil, page: Int = 1, limit: Int = 20) async throws -> SearchResponse {
        var path = "/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&type=\(type)&page=\(page)&limit=\(limit)"
        if let projectId = projectId {
            path += "&projectId=\(projectId)"
        }
        return try await get(path)
    }
    
    func getProjects() async throws -> [ProjectDTO] {
        try await get("/projects")
    }
    
    func getProject(id: String) async throws -> ProjectDTO {
        try await get("/projects/\(id)")
    }
    
    func createProject(_ request: CreateProjectRequest) async throws -> ProjectDTO {
        try await post("/projects", body: request)
    }
    
    func updateProject(id: String, _ request: UpdateProjectRequest) async throws -> ProjectDTO {
        try await patch("/projects/\(id)", body: request)
    }
    
    func deleteProject(id: String) async throws {
        try await delete("/projects/\(id)")
    }
    
    func getPhotos(projectId: String, page: Int = 1, limit: Int = 50) async throws -> PaginatedResponse<PhotoDTO> {
        try await get("/projects/\(projectId)/photos?page=\(page)&limit=\(limit)")
    }
    
    func createPhoto(_ request: CreatePhotoRequest) async throws -> PhotoDTO {
        try await post("/photos", body: request)
    }
    
    func getUploadUrl(projectId: String, filename: String, contentType: String) async throws -> UploadUrlResponse {
        let body = ["filename": filename, "contentType": contentType]
        return try await post("/projects/\(projectId)/photos/upload-url", body: body)
    }
    
    func uploadMedia(to url: URL, data: Data, contentType: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await session.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.uploadFailed
        }
    }
    
    func createFolder(projectId: String, _ request: CreateFolderRequest) async throws -> FolderDTO {
        try await post("/projects/\(projectId)/folders", body: request)
    }
    
    func createComment(photoId: String, text: String) async throws -> CommentDTO {
        try await post("/photos/\(photoId)/comments", body: ["text": text])
    }
    
    func createShareLink(projectId: String, _ request: CreateShareLinkRequest) async throws -> ShareLinkDTO {
        try await post("/projects/\(projectId)/share", body: request)
    }
    
    func transcribeVoiceNote(photoId: String, audioData: Data) async throws -> TranscriptionResponse {
        let boundary = UUID().uuidString
        var request = try buildRequest("/photos/\(photoId)/voice-note", method: "POST")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"voice.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        let (data, response) = try await session.upload(for: request, from: body)
        try validateResponse(response)
        return try decoder.decode(TranscriptionResponse.self, from: data)
    }
    
    // MARK: - Push Notifications
    
    func registerDeviceToken(token: String, platform: String) async throws {
        let body = RegisterDeviceRequest(token: token, platform: platform)
        let _: EmptyResponse = try await post("/notifications/register", body: body)
    }
    
    func unregisterDeviceToken(token: String) async throws {
        let body = ["token": token]
        let _: EmptyResponse = try await post("/notifications/unregister", body: body)
    }
    
    func getNotificationPreferences() async throws -> NotificationPreferencesDTO {
        try await get("/notifications/preferences")
    }
    
    func updateNotificationPreferences(_ preferences: NotificationPreferencesDTO) async throws -> NotificationPreferencesDTO {
        try await patch("/notifications/preferences", body: preferences)
    }
    
    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try buildRequest(path, method: "GET")
        return try await execute(request)
    }
    
    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path, method: "POST")
        request.httpBody = try encoder.encode(body)
        return try await execute(request)
    }
    
    private func patch<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path, method: "PATCH")
        request.httpBody = try encoder.encode(body)
        return try await execute(request)
    }
    
    private func delete(_ path: String) async throws {
        let request = try buildRequest(path, method: "DELETE")
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }
    
    private func buildRequest(_ path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: "\(Constants.API.fullBaseURL)\(path)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = keychainService.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 422:
            throw APIError.validationError
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.unknown(httpResponse.statusCode)
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case validationError
    case serverError
    case uploadFailed
    case unknown(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Please sign in again"
        case .forbidden:
            return "You don't have permission to perform this action"
        case .notFound:
            return "Resource not found"
        case .validationError:
            return "Invalid data provided"
        case .serverError:
            return "Server error. Please try again later"
        case .uploadFailed:
            return "Failed to upload media"
        case .unknown(let code):
            return "Request failed with status \(code)"
        }
    }
}
