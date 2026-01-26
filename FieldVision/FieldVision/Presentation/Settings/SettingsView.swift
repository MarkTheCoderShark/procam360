import SwiftUI
// RevenueCatUI temporarily disabled
// import RevenueCatUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var purchaseService = PurchaseService.shared
    @State private var showingLogoutAlert = false
    @State private var showingClearCacheAlert = false
    @State private var cacheCleared = false
    @State private var showingWhatsNew = false
    @State private var showingPaywall = false
    @State private var showingCustomerCenter = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AccountSettingsView()
                    } label: {
                        profileRow
                    }
                }

                Section {
                    subscriptionRow
                }

                Section("Preferences") {
                    NavigationLink {
                        CameraSettingsView()
                    } label: {
                        Label("Camera Settings", systemImage: "camera")
                    }

                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                }

                Section("Storage") {
                    storageRow

                    NavigationLink {
                        SavedReportsView()
                    } label: {
                        Label("Saved Reports", systemImage: "doc.richtext")
                    }

                    Button(role: .destructive) {
                        showingClearCacheAlert = true
                    } label: {
                        Label("Clear Cache", systemImage: "trash")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .foregroundStyle(FVColors.secondaryLabel)
                    }

                    Button {
                        showingWhatsNew = true
                    } label: {
                        Label("What's New", systemImage: "sparkles")
                    }

                    Link(destination: URL(string: "https://fieldvision.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    Link(destination: URL(string: "https://fieldvision.app/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    authViewModel.logout()
                }
            } message: {
                Text("Are you sure you want to sign out? Unsynced data will be preserved and synced when you sign back in.")
            }
            .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    MediaStorage.shared.clearAllMedia()
                    cacheCleared = true
                }
            } message: {
                Text("This will remove \(MediaStorage.shared.formattedMediaSize) of cached media. Photos synced to the cloud will not be affected.")
            }
            .alert("Cache Cleared", isPresented: $cacheCleared) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Local cache has been cleared successfully.")
            }
            .sheet(isPresented: $showingWhatsNew) {
                WhatsNewView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            // Customer center disabled while RevenueCat is disabled
            // .presentCustomerCenter(isPresented: $showingCustomerCenter)
        }
    }

    private var subscriptionRow: some View {
        Button {
            // Since RevenueCat is disabled and everyone has Pro, just show paywall info
            if purchaseService.isPro {
                showingCustomerCenter = true
            } else {
                showingPaywall = true
            }
        } label: {
            HStack(spacing: FVSpacing.md) {
                ZStack {
                    Circle()
                        .fill(purchaseService.isPro ? Color.yellow.opacity(0.2) : FVColors.Fallback.primary.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: purchaseService.isPro ? "crown.fill" : "star.fill")
                        .foregroundStyle(purchaseService.isPro ? .yellow : FVColors.Fallback.primary)
                }

                VStack(alignment: .leading, spacing: FVSpacing.xxxs) {
                    Text(purchaseService.isPro ? "Proflow Inspect Pro" : "Upgrade to Pro")
                        .font(FVTypography.headline)
                        .foregroundStyle(FVColors.label)

                    Text(purchaseService.isPro ? "Manage subscription" : "Unlock all features")
                        .font(FVTypography.caption)
                        .foregroundStyle(FVColors.secondaryLabel)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(FVColors.tertiaryLabel)
            }
        }
    }

    private var profileRow: some View {
        HStack(spacing: FVSpacing.md) {
            Circle()
                .fill(FVColors.Fallback.primary.opacity(0.2))
                .frame(width: 56, height: 56)
                .overlay {
                    Text(authViewModel.currentUserName?.prefix(2).uppercased() ?? "?")
                        .font(FVTypography.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(FVColors.Fallback.primary)
                }

            VStack(alignment: .leading, spacing: FVSpacing.xxxs) {
                Text(authViewModel.currentUserName ?? "User")
                    .font(FVTypography.headline)
                    .foregroundStyle(FVColors.label)

                Text("Manage account")
                    .font(FVTypography.caption)
                    .foregroundStyle(FVColors.secondaryLabel)
            }
        }
    }

    private var storageRow: some View {
        HStack {
            Label("Local Storage", systemImage: "internaldrive")

            Spacer()

            Text(MediaStorage.shared.formattedMediaSize)
                .foregroundStyle(FVColors.secondaryLabel)
        }
    }
}

struct CameraSettingsView: View {
    @AppStorage(Constants.UserDefaultsKeys.preferredCameraMode) private var preferredCameraMode = "photo"
    @AppStorage(Constants.UserDefaultsKeys.autoVoiceNotePrompt) private var autoVoiceNotePrompt = true

    var body: some View {
        Form {
            Section("Default Mode") {
                Picker("Default Camera Mode", selection: $preferredCameraMode) {
                    Text("Photo").tag("photo")
                    Text("Video").tag("video")
                }
                .pickerStyle(.segmented)
            }

            Section("Voice Notes") {
                Toggle("Prompt for voice note after capture", isOn: $autoVoiceNotePrompt)
            }

            Section(footer: Text("Voice notes are transcribed using on-device speech recognition when available.")) {
                EmptyView()
            }
        }
        .navigationTitle("Camera Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationSettingsView: View {
    @State private var commentsEnabled = true
    @State private var syncEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle("Comment notifications", isOn: $commentsEnabled)
                Toggle("Sync status notifications", isOn: $syncEnabled)
            }

            Section {
                Button("Open System Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AccountSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingDeleteAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showingError = false

    private let apiClient = APIClient.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(authViewModel.currentUserName ?? "—")
                        .foregroundStyle(FVColors.secondaryLabel)
                }

                HStack {
                    Text("Email")
                    Spacer()
                    Text(authViewModel.currentUserEmail ?? "—")
                        .foregroundStyle(FVColors.secondaryLabel)
                }
            }

            Section("Security") {
                NavigationLink {
                    ChangePasswordView()
                } label: {
                    Text("Change Password")
                }
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("Delete Account")
                        }
                        Spacer()
                    }
                }
                .disabled(isDeleting)
            } footer: {
                Text("Deleting your account will permanently remove all your data and cannot be undone.")
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                showingDeleteConfirmation = true
            }
        } message: {
            Text("Are you sure you want to delete your account? This will permanently remove all your projects, photos, and data.")
        }
        .alert("Final Confirmation", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Forever", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("This action CANNOT be undone. All your data will be permanently deleted. Type 'DELETE' to confirm... just kidding, but are you really sure?")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "An unknown error occurred")
        }
    }

    private func deleteAccount() async {
        isDeleting = true

        do {
            try await apiClient.deleteAccount()
            await MainActor.run {
                authViewModel.logout()
            }
        } catch let error as APIError {
            deleteError = error.localizedDescription
            showingError = true
        } catch {
            deleteError = error.localizedDescription
            showingError = true
        }

        isDeleting = false
    }
}

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false

    private let apiClient = APIClient.shared
    private let keychainService = KeychainService.shared

    var body: some View {
        Form {
            Section {
                SecureField("Current Password", text: $currentPassword)
                    .textContentType(.password)
                SecureField("New Password", text: $newPassword)
                    .textContentType(.newPassword)
                SecureField("Confirm New Password", text: $confirmPassword)
                    .textContentType(.newPassword)
            }

            Section {
                if newPassword.count > 0 && newPassword.count < 8 {
                    Label("Password must be at least 8 characters", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(FVColors.warning)
                        .font(FVTypography.caption)
                }

                if !confirmPassword.isEmpty && newPassword != confirmPassword {
                    Label("Passwords don't match", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(FVColors.warning)
                        .font(FVTypography.caption)
                }
            }

            Section {
                Button {
                    Task { await updatePassword() }
                } label: {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Update Password")
                        }
                        Spacer()
                    }
                }
                .disabled(!isFormValid || isLoading)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Password Changed", isPresented: $showingSuccess) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Your password has been updated successfully.")
        }
    }

    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword
    }

    private func updatePassword() async {
        isLoading = true

        do {
            let response = try await apiClient.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )

            keychainService.setAccessToken(response.accessToken)
            keychainService.setRefreshToken(response.refreshToken)

            showingSuccess = true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            showingError = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }

        isLoading = false
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
