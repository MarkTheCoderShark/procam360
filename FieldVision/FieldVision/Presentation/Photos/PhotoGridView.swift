import SwiftUI
import SwiftData

struct PhotoGridView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext

    @State private var selectedPhoto: Photo?
    @State private var selectedFolder: Folder?
    @State private var showingCreateFolder = false
    @State private var showingFolderPicker = false
    @State private var isSelectionMode = false
    @State private var selectedPhotos: Set<UUID> = []
    @State private var showingDeleteConfirmation = false
    @State private var showingMoveSheet = false

    private var displayedPhotos: [Photo] {
        if let folder = selectedFolder {
            return folder.photos.sorted { $0.capturedAt > $1.capturedAt }
        }
        return project.photos.sorted { $0.capturedAt > $1.capturedAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Folder filter bar
            folderFilterBar

            // Photo grid
            if displayedPhotos.isEmpty {
                emptyState
            } else {
                photoGridContent
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo, project: project)
        }
        .sheet(isPresented: $showingCreateFolder) {
            CreateFolderView(project: project)
        }
        .sheet(isPresented: $showingMoveSheet) {
            MoveToFolderView(
                project: project,
                photoIds: selectedPhotos,
                onComplete: {
                    selectedPhotos.removeAll()
                    isSelectionMode = false
                }
            )
        }
        .confirmationDialog(
            "Delete \(selectedPhotos.count) photo\(selectedPhotos.count == 1 ? "" : "s")?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteSelectedPhotos()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var folderFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FVSpacing.sm) {
                // "All Photos" chip
                FilterChip(
                    title: "All Photos",
                    count: project.photos.count,
                    isSelected: selectedFolder == nil,
                    action: { selectedFolder = nil }
                )

                // Folder chips
                ForEach(project.folders) { folder in
                    FilterChip(
                        title: folder.name,
                        count: folder.photoCount,
                        isSelected: selectedFolder?.id == folder.id,
                        action: { selectedFolder = folder }
                    )
                }

                // Add folder button
                Button {
                    showingCreateFolder = true
                } label: {
                    HStack(spacing: FVSpacing.xxs) {
                        Image(systemName: "folder.badge.plus")
                        Text("New Folder")
                    }
                    .font(FVTypography.caption)
                    .foregroundStyle(FVColors.Fallback.primary)
                    .padding(.horizontal, FVSpacing.sm)
                    .padding(.vertical, FVSpacing.xs)
                    .background(FVColors.Fallback.primary.opacity(0.1))
                    .cornerRadius(FVRadius.full)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, FVSpacing.sm)
        }
        .background(FVColors.secondaryBackground)
    }

    private var emptyState: some View {
        VStack(spacing: FVSpacing.md) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(FVColors.tertiaryLabel)

            if selectedFolder != nil {
                Text("No photos in this folder")
                    .font(FVTypography.subheadline)
                    .foregroundStyle(FVColors.secondaryLabel)

                Text("Take photos and assign them to this folder")
                    .font(FVTypography.caption)
                    .foregroundStyle(FVColors.tertiaryLabel)
                    .multilineTextAlignment(.center)
            } else {
                Text("No photos yet")
                    .font(FVTypography.subheadline)
                    .foregroundStyle(FVColors.secondaryLabel)

                Text("Tap the camera button to start capturing")
                    .font(FVTypography.caption)
                    .foregroundStyle(FVColors.tertiaryLabel)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var photoGridContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Selection mode toolbar
                if !displayedPhotos.isEmpty {
                    HStack {
                        Button(isSelectionMode ? "Done" : "Select") {
                            withAnimation {
                                isSelectionMode.toggle()
                                if !isSelectionMode {
                                    selectedPhotos.removeAll()
                                }
                            }
                        }
                        .font(FVTypography.subheadline)

                        Spacer()

                        Text("\(displayedPhotos.count) photos")
                            .font(FVTypography.caption)
                            .foregroundStyle(FVColors.secondaryLabel)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, FVSpacing.xs)
                }

                // Photo grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: Constants.UI.gridSpacing),
                    GridItem(.flexible(), spacing: Constants.UI.gridSpacing),
                    GridItem(.flexible(), spacing: Constants.UI.gridSpacing)
                ], spacing: Constants.UI.gridSpacing) {
                    ForEach(displayedPhotos) { photo in
                        SelectablePhotoThumbnail(
                            photo: photo,
                            isSelected: selectedPhotos.contains(photo.id),
                            isSelectionMode: isSelectionMode
                        )
                        .onTapGesture {
                            if isSelectionMode {
                                toggleSelection(photo.id)
                            } else {
                                selectedPhoto = photo
                            }
                        }
                        .onLongPressGesture {
                            if !isSelectionMode {
                                withAnimation {
                                    isSelectionMode = true
                                    selectedPhotos.insert(photo.id)
                                }
                            }
                        }
                    }
                }
                .padding(Constants.UI.gridSpacing)
                .padding(.bottom, 100)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelectionMode && !selectedPhotos.isEmpty {
                bulkActionBar
            }
        }
    }

    private var bulkActionBar: some View {
        HStack(spacing: FVSpacing.lg) {
            Button {
                showingMoveSheet = true
            } label: {
                VStack(spacing: FVSpacing.xxxs) {
                    Image(systemName: "folder")
                        .font(.title2)
                    Text("Move")
                        .font(FVTypography.caption2)
                }
            }

            Spacer()

            Text("\(selectedPhotos.count) selected")
                .font(FVTypography.subheadline)
                .foregroundStyle(FVColors.secondaryLabel)

            Spacer()

            Button {
                showingDeleteConfirmation = true
            } label: {
                VStack(spacing: FVSpacing.xxxs) {
                    Image(systemName: "trash")
                        .font(.title2)
                    Text("Delete")
                        .font(FVTypography.caption2)
                }
                .foregroundStyle(FVColors.error)
            }
        }
        .padding(.horizontal, FVSpacing.xl)
        .padding(.vertical, FVSpacing.md)
        .background(.ultraThinMaterial)
    }

    private func toggleSelection(_ id: UUID) {
        if selectedPhotos.contains(id) {
            selectedPhotos.remove(id)
        } else {
            selectedPhotos.insert(id)
        }
    }

    private func deleteSelectedPhotos() {
        for photo in displayedPhotos where selectedPhotos.contains(photo.id) {
            if let localPath = photo.localURL?.path, !localPath.isEmpty {
                MediaStorage.shared.deleteMedia(at: localPath)
            }
            if let thumbnailPath = photo.thumbnailLocalPath {
                MediaStorage.shared.deleteMedia(at: thumbnailPath)
            }
            modelContext.delete(photo)
        }

        selectedPhotos.removeAll()
        isSelectionMode = false
    }
}

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FVSpacing.xxs) {
                Text(title)
                Text("(\(count))")
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : FVColors.secondaryLabel)
            }
            .font(FVTypography.caption)
            .foregroundStyle(isSelected ? .white : FVColors.label)
            .padding(.horizontal, FVSpacing.sm)
            .padding(.vertical, FVSpacing.xs)
            .background(isSelected ? FVColors.Fallback.primary : FVColors.tertiaryBackground)
            .cornerRadius(FVRadius.full)
        }
    }
}

struct MoveToFolderView: View {
    let project: Project
    let photoIds: Set<UUID>
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                // Option to remove from folder (set to no folder)
                Button {
                    movePhotos(to: nil)
                } label: {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundStyle(FVColors.secondaryLabel)
                            .frame(width: 32)

                        VStack(alignment: .leading) {
                            Text("No Folder")
                                .foregroundStyle(FVColors.label)
                            Text("Remove from folder")
                                .font(FVTypography.caption)
                                .foregroundStyle(FVColors.secondaryLabel)
                        }
                    }
                }

                // Folder options
                ForEach(project.folders) { folder in
                    Button {
                        movePhotos(to: folder)
                    } label: {
                        HStack {
                            Image(systemName: folder.folderType.iconName)
                                .foregroundStyle(FVColors.Fallback.primary)
                                .frame(width: 32)

                            VStack(alignment: .leading) {
                                Text(folder.name)
                                    .foregroundStyle(FVColors.label)
                                Text("\(folder.photoCount) photos")
                                    .font(FVTypography.caption)
                                    .foregroundStyle(FVColors.secondaryLabel)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func movePhotos(to targetFolder: Folder?) {
        for photo in project.photos where photoIds.contains(photo.id) {
            photo.folder = targetFolder
            photo.updatedAt = Date()
            photo.syncStatus = .pending
        }

        project.updatedAt = Date()
        dismiss()
        onComplete()
    }
}

#Preview {
    PhotoGridView(project: Project(name: "Test", address: "123 Main St"))
}
