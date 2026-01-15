import SwiftUI
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: AuthError?

    @Published var email = ""
    @Published var password = ""
    @Published var name = ""
    @Published var confirmPassword = ""

    @Published var currentUserId: UUID?
    @Published var currentUserName: String?
    @Published var currentUserEmail: String?

    private let apiClient = APIClient.shared
    private let keychainService = KeychainService.shared

    init() {
        checkExistingAuth()
    }

    private func checkExistingAuth() {
        if let token = keychainService.getAccessToken(),
           let userId = keychainService.getUserId() {
            self.currentUserId = userId
            self.isAuthenticated = true
            Task {
                await refreshUserInfo()
            }
        }
    }

    func login() async {
        guard validateLoginInput() else { return }

        isLoading = true
        error = nil

        do {
            let response = try await apiClient.login(email: email, password: password)
            handleAuthSuccess(response: response)
        } catch let apiError as APIError {
            error = .api(apiError.localizedDescription)
        } catch {
            self.error = .unknown(error.localizedDescription)
        }

        isLoading = false
    }

    func register() async {
        guard validateRegisterInput() else { return }

        isLoading = true
        error = nil

        do {
            let response = try await apiClient.register(email: email, password: password, name: name)
            handleAuthSuccess(response: response)
        } catch let apiError as APIError {
            error = .api(apiError.localizedDescription)
        } catch {
            self.error = .unknown(error.localizedDescription)
        }

        isLoading = false
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleIDCredential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                error = .apple("Failed to get Apple ID credentials")
                return
            }

            isLoading = true
            error = nil

            let fullName = [
                appleIDCredential.fullName?.givenName,
                appleIDCredential.fullName?.familyName
            ].compactMap { $0 }.joined(separator: " ")

            do {
                let response = try await apiClient.appleSignIn(
                    identityToken: tokenString,
                    name: fullName.isEmpty ? nil : fullName,
                    email: appleIDCredential.email
                )
                handleAuthSuccess(response: response)
            } catch {
                self.error = .apple(error.localizedDescription)
            }

            isLoading = false

        case .failure(let authError):
            if (authError as NSError).code != ASAuthorizationError.canceled.rawValue {
                error = .apple(authError.localizedDescription)
            }
        }
    }

    func logout() {
        keychainService.clearAll()
        currentUserId = nil
        currentUserName = nil
        currentUserEmail = nil
        isAuthenticated = false
        clearInputs()
    }

    // MARK: - Test Account (Development Only)

    func loginWithTestAccount() {
        let testUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let testToken = "test_token_\(UUID().uuidString)"

        keychainService.setAccessToken(testToken)
        keychainService.setRefreshToken(testToken)
        keychainService.setUserId(testUserId)

        currentUserId = testUserId
        currentUserName = "Test Admin"
        currentUserEmail = "test@procam360.app"
        isAuthenticated = true
        clearInputs()
    }

    static let isTestModeEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    private func handleAuthSuccess(response: AuthResponse) {
        keychainService.setAccessToken(response.accessToken)
        keychainService.setRefreshToken(response.refreshToken)
        keychainService.setUserId(response.user.id)

        currentUserId = response.user.id
        currentUserName = response.user.name
        currentUserEmail = response.user.email
        isAuthenticated = true
        clearInputs()
    }

    private func refreshUserInfo() async {
        do {
            let user = try await apiClient.getCurrentUser()
            currentUserName = user.name
            currentUserEmail = user.email
        } catch {
            // Silent fail - we have cached auth
        }
    }

    private func validateLoginInput() -> Bool {
        guard !email.isEmpty else {
            error = .validation("Email is required")
            return false
        }
        guard email.contains("@") else {
            error = .validation("Please enter a valid email")
            return false
        }
        guard !password.isEmpty else {
            error = .validation("Password is required")
            return false
        }
        return true
    }

    private func validateRegisterInput() -> Bool {
        guard !name.isEmpty else {
            error = .validation("Name is required")
            return false
        }
        guard validateLoginInput() else { return false }
        guard password.count >= 8 else {
            error = .validation("Password must be at least 8 characters")
            return false
        }
        guard password == confirmPassword else {
            error = .validation("Passwords do not match")
            return false
        }
        return true
    }

    private func clearInputs() {
        email = ""
        password = ""
        name = ""
        confirmPassword = ""
    }
}

enum AuthError: LocalizedError, Equatable {
    case validation(String)
    case api(String)
    case apple(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .validation(let message),
             .api(let message),
             .apple(let message),
             .unknown(let message):
            return message
        }
    }
}
