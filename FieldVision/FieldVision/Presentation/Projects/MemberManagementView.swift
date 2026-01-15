import SwiftUI
import SwiftData

struct MemberManagementView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var viewModel = MemberManagementViewModel()
    @State private var showingInviteSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Team Members") {
                    ForEach(viewModel.members) { member in
                        MemberRow(member: member, currentUserIsAdmin: viewModel.isCurrentUserAdmin) {
                            viewModel.removeMember(member)
                        } onRoleChange: { newRole in
                            viewModel.updateRole(for: member, to: newRole)
                        }
                    }
                }
                
                if viewModel.pendingInvites.count > 0 {
                    Section("Pending Invites") {
                        ForEach(viewModel.pendingInvites) { invite in
                            PendingInviteRow(invite: invite) {
                                viewModel.cancelInvite(invite)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if viewModel.isCurrentUserAdmin {
                        Button {
                            showingInviteSheet = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingInviteSheet) {
                InviteMemberView(project: project, viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadMembers(for: project)
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }
}

struct MemberRow: View {
    let member: ProjectMemberInfo
    let currentUserIsAdmin: Bool
    let onRemove: () -> Void
    let onRoleChange: (MemberRole) -> Void
    
    var body: some View {
        HStack(spacing: FVSpacing.md) {
            Circle()
                .fill(FVColors.Fallback.primary.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(member.initials)
                        .font(FVTypography.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(FVColors.Fallback.primary)
                }
            
            VStack(alignment: .leading, spacing: FVSpacing.xxxs) {
                Text(member.name)
                    .font(FVTypography.body)
                    .foregroundStyle(FVColors.label)
                
                Text(member.email)
                    .font(FVTypography.caption)
                    .foregroundStyle(FVColors.secondaryLabel)
            }
            
            Spacer()
            
            if currentUserIsAdmin && !member.isCurrentUser {
                Menu {
                    ForEach(MemberRole.allCases, id: \.self) { role in
                        Button {
                            onRoleChange(role)
                        } label: {
                            Label(role.displayName, systemImage: member.role == role ? "checkmark" : "")
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Label("Remove from Project", systemImage: "person.badge.minus")
                    }
                } label: {
                    HStack(spacing: FVSpacing.xxs) {
                        Text(member.role.displayName)
                            .font(FVTypography.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(FVColors.secondaryLabel)
                    .padding(.horizontal, FVSpacing.sm)
                    .padding(.vertical, FVSpacing.xxs)
                    .background(FVColors.tertiaryBackground)
                    .cornerRadius(FVRadius.sm)
                }
            } else {
                Text(member.role.displayName)
                    .font(FVTypography.caption)
                    .foregroundStyle(FVColors.secondaryLabel)
                    .padding(.horizontal, FVSpacing.sm)
                    .padding(.vertical, FVSpacing.xxs)
                    .background(FVColors.tertiaryBackground)
                    .cornerRadius(FVRadius.sm)
            }
        }
    }
}

struct PendingInviteRow: View {
    let invite: PendingInvite
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: FVSpacing.md) {
            Circle()
                .fill(FVColors.tertiaryBackground)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "envelope")
                        .foregroundStyle(FVColors.tertiaryLabel)
                }
            
            VStack(alignment: .leading, spacing: FVSpacing.xxxs) {
                Text(invite.email)
                    .font(FVTypography.body)
                    .foregroundStyle(FVColors.label)
                
                Text("Invited \(invite.invitedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(FVTypography.caption)
                    .foregroundStyle(FVColors.tertiaryLabel)
            }
            
            Spacer()
            
            Button(role: .destructive) {
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(FVColors.tertiaryLabel)
            }
        }
    }
}

struct InviteMemberView: View {
    let project: Project
    @ObservedObject var viewModel: MemberManagementViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var selectedRole: MemberRole = .crew
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email address", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section("Role") {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(MemberRole.allCases, id: \.self) { role in
                            VStack(alignment: .leading) {
                                Text(role.displayName)
                                Text(role.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(role)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                
                Section {
                    Text(selectedRole.permissionsDescription)
                        .font(FVTypography.caption)
                        .foregroundStyle(FVColors.secondaryLabel)
                }
            }
            .navigationTitle("Invite Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send Invite") {
                        Task {
                            await viewModel.inviteMember(email: email, role: selectedRole, to: project)
                            if viewModel.error == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(email.isEmpty || !email.contains("@"))
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

@MainActor
final class MemberManagementViewModel: ObservableObject {
    @Published var members: [ProjectMemberInfo] = []
    @Published var pendingInvites: [PendingInvite] = []
    @Published var isCurrentUserAdmin = false
    @Published var isLoading = false
    @Published var error: String?
    
    private let apiClient = APIClient.shared
    private var projectId: String?
    
    func loadMembers(for project: Project) {
        guard let remoteId = project.remoteId else {
            // Use local data for unsynced projects
            return
        }
        
        projectId = remoteId
        isLoading = true
        
        Task {
            do {
                let projectDetail = try await apiClient.getProject(id: remoteId)
                // Parse members from project detail response
                // This would be populated from the API response
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    func inviteMember(email: String, role: MemberRole, to project: Project) async {
        guard let projectId = project.remoteId else {
            error = "Project must be synced before inviting members"
            return
        }
        
        isLoading = true
        
        // API call would go here
        // For now, add to pending invites locally
        let invite = PendingInvite(id: UUID().uuidString, email: email, role: role, invitedAt: Date())
        pendingInvites.append(invite)
        
        isLoading = false
    }
    
    func removeMember(_ member: ProjectMemberInfo) {
        members.removeAll { $0.id == member.id }
        // API call to remove member
    }
    
    func updateRole(for member: ProjectMemberInfo, to newRole: MemberRole) {
        if let index = members.firstIndex(where: { $0.id == member.id }) {
            members[index].role = newRole
        }
        // API call to update role
    }
    
    func cancelInvite(_ invite: PendingInvite) {
        pendingInvites.removeAll { $0.id == invite.id }
        // API call to cancel invite
    }
}

struct ProjectMemberInfo: Identifiable {
    let id: String
    let name: String
    let email: String
    var role: MemberRole
    let isCurrentUser: Bool
    
    var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

struct PendingInvite: Identifiable {
    let id: String
    let email: String
    let role: MemberRole
    let invitedAt: Date
}

enum MemberRole: String, CaseIterable, Codable {
    case admin = "ADMIN"
    case crew = "CREW"
    case viewer = "VIEWER"
    
    var displayName: String {
        switch self {
        case .admin: return "Admin"
        case .crew: return "Crew"
        case .viewer: return "Viewer"
        }
    }
    
    var description: String {
        switch self {
        case .admin: return "Full access to manage project"
        case .crew: return "Can add photos and comments"
        case .viewer: return "View-only access"
        }
    }
    
    var permissionsDescription: String {
        switch self {
        case .admin:
            return "Admins can add/remove members, delete the project, create share links, and perform all actions."
        case .crew:
            return "Crew members can capture photos, add comments, organize into folders, but cannot manage members or delete the project."
        case .viewer:
            return "Viewers can only view photos and comments. They cannot upload or modify anything."
        }
    }
}

#Preview {
    MemberManagementView(project: Project(name: "Test", address: "123 Main St"))
}
