import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext

    @State private var selectedView: ProjectViewType = .photos
    @State private var showingCamera = false
    @State private var showingShareSheet = false
    @State private var showingEditProject = false
    @State private var showingReportConfig = false
    @State private var showingPaywall = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @StateObject private var purchaseService = PurchaseService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                projectHeader

                Picker("View", selection: $selectedView) {
                    ForEach(ProjectViewType.allCases, id: \.self) { viewType in
                        Label(viewType.title, systemImage: viewType.icon)
                            .tag(viewType)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, FVSpacing.sm)

                selectedViewContent
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FVFloatingActionButton(icon: "camera.fill") {
                        showingCamera = true
                    }
                    .padding(.trailing, FVSpacing.lg)
                    .padding(.bottom, FVSpacing.lg)
                }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("Share Project", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingEditProject = true
                    } label: {
                        Label("Edit Project", systemImage: "pencil")
                    }

                    Button {
                        if purchaseService.isPro {
                            showingReportConfig = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Label("Generate Report", systemImage: "doc.richtext")
                    }

                    Divider()

                    Menu("Change Status") {
                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            Button {
                                project.status = status
                                project.updatedAt = Date()
                            } label: {
                                Label(status.displayName, systemImage: project.status == status ? "checkmark" : status.iconName)
                            }
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Project", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(project: project)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareConfigView(project: project)
        }
        .sheet(isPresented: $showingEditProject) {
            EditProjectView(project: project)
        }
        .sheet(isPresented: $showingReportConfig) {
            ReportConfigView(project: project)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .alert("Delete Project?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteProject()
            }
        } message: {
            Text("Are you sure you want to delete \"\(project.name)\"? This will permanently remove all photos, folders, and data associated with this project. This action cannot be undone.")
        }
        .disabled(isDeleting)
    }

    private func deleteProject() {
        isDeleting = true

        let remoteId = project.remoteId

        // Delete from local storage
        modelContext.delete(project)

        // If the project was synced to remote, delete from server
        if let remoteId = remoteId {
            Task {
                do {
                    let apiClient = APIClient.shared
                    try await apiClient.deleteProject(id: remoteId)
                } catch {
                    print("Failed to delete project from server: \(error)")
                }
            }
        }

        // Dismiss the view
        dismiss()
    }

    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: FVSpacing.xs) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(FVColors.Fallback.primary)

                Text(project.address)
                    .font(FVTypography.subheadline)
                    .foregroundStyle(FVColors.secondaryLabel)
                    .lineLimit(1)
            }

            HStack(spacing: FVSpacing.md) {
                Label("\(project.photoCount) photos", systemImage: "photo")
                Label("\(project.folderCount) folders", systemImage: "folder")

                Spacer()

                statusBadge
            }
            .font(FVTypography.caption)
            .foregroundStyle(FVColors.tertiaryLabel)

            if project.syncStatus == .pending || project.syncStatus == .failed {
                syncStatusBanner
            }
        }
        .padding(.horizontal)
        .padding(.vertical, FVSpacing.sm)
        .background(FVColors.secondaryBackground)
    }

    private var statusBadge: some View {
        Text(project.status.displayName)
            .font(FVTypography.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, FVSpacing.xs)
            .padding(.vertical, FVSpacing.xxxs)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .cornerRadius(FVRadius.xs)
    }

    private var statusColor: Color {
        switch project.status {
        case .walkthrough: return FVColors.statusWalkthrough
        case .inProgress: return FVColors.statusInProgress
        case .completed: return FVColors.statusCompleted
        }
    }

    private var syncStatusBanner: some View {
        HStack(spacing: FVSpacing.xs) {
            Image(systemName: project.syncStatus == .failed ? "exclamationmark.triangle" : "arrow.triangle.2.circlepath")
                .foregroundStyle(project.syncStatus == .failed ? FVColors.warning : FVColors.Fallback.primary)

            Text(project.syncStatus == .failed ? "Sync failed. Will retry automatically." : "Waiting to sync...")
                .font(FVTypography.caption)
                .foregroundStyle(FVColors.secondaryLabel)
        }
        .padding(FVSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FVColors.tertiaryBackground)
        .cornerRadius(FVRadius.xs)
    }

    @ViewBuilder
    private var selectedViewContent: some View {
        switch selectedView {
        case .photos:
            PhotoGridView(project: project)
        case .timeline:
            TimelineView(project: project)
        case .map:
            PhotoMapView(project: project)
        }
    }
}

enum ProjectViewType: String, CaseIterable {
    case photos
    case timeline
    case map

    var title: String {
        switch self {
        case .photos: return "Photos"
        case .timeline: return "Timeline"
        case .map: return "Map"
        }
    }

    var icon: String {
        switch self {
        case .photos: return "photo.on.rectangle"
        case .timeline: return "clock"
        case .map: return "map"
        }
    }
}

struct EditProjectView: View {
    @Bindable var project: Project
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var address: String = ""
    @State private var clientName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project Name", text: $name)
                    TextField("Client Name", text: $clientName)
                }

                Section {
                    TextField("Address", text: $address)
                }
            }
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                name = project.name
                address = project.address
                clientName = project.clientName ?? ""
            }
        }
    }

    private func saveChanges() {
        project.name = name
        project.address = address
        project.clientName = clientName.isEmpty ? nil : clientName
        project.updatedAt = Date()
        project.syncStatus = .pending
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ProjectDetailView(project: Project(name: "Test Project", address: "123 Main St"))
    }
    .modelContainer(for: Project.self, inMemory: true)
}
