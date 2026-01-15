import SwiftUI

struct FolderGridView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext

    @State private var showingCreateFolder = false
    @State private var selectedFolder: Folder?

    private let columns = [
        GridItem(.flexible(), spacing: FVSpacing.sm),
        GridItem(.flexible(), spacing: FVSpacing.sm)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: FVSpacing.sm) {
                ForEach(project.folders) { folder in
                    FolderCard(folder: folder)
                        .onTapGesture {
                            selectedFolder = folder
                        }
                }

                addFolderCard
            }
            .padding()
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $showingCreateFolder) {
            CreateFolderView(project: project)
        }
        .sheet(item: $selectedFolder) { folder in
            FolderDetailView(folder: folder, project: project)
        }
    }

    private var addFolderCard: some View {
        Button {
            showingCreateFolder = true
        } label: {
            VStack(spacing: FVSpacing.sm) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(FVColors.Fallback.primary)

                Text("Add Folder")
                    .font(FVTypography.subheadline)
                    .foregroundStyle(FVColors.Fallback.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(FVColors.Fallback.primary.opacity(0.1))
            .cornerRadius(FVRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: FVRadius.md)
                    .stroke(FVColors.Fallback.primary, style: StrokeStyle(lineWidth: 2, dash: [8]))
            )
        }
    }
}

struct FolderCard: View {
    let folder: Folder

    var body: some View {
        VStack(alignment: .leading, spacing: FVSpacing.xs) {
            ZStack {
                if let coverPhoto = folder.coverPhoto,
                   let url = coverPhoto.thumbnailURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        folderPlaceholder
                    }
                } else {
                    folderPlaceholder
                }
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: FVRadius.sm))

            VStack(alignment: .leading, spacing: FVSpacing.xxxs) {
                Text(folder.name)
                    .font(FVTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(FVColors.label)
                    .lineLimit(1)

                Text("\(folder.photoCount) photos")
                    .font(FVTypography.caption)
                    .foregroundStyle(FVColors.secondaryLabel)
            }
        }
        .padding(FVSpacing.sm)
        .background(FVColors.secondaryBackground)
        .cornerRadius(FVRadius.md)
    }

    private var folderPlaceholder: some View {
        Rectangle()
            .fill(FVColors.tertiaryBackground)
            .overlay {
                Image(systemName: folder.folderType.iconName)
                    .font(.largeTitle)
                    .foregroundStyle(FVColors.tertiaryLabel)
            }
    }
}

struct CreateFolderView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var folderType: FolderType = .custom

    var body: some View {
        NavigationStack {
            Form {
                Section("Folder Name") {
                    TextField("e.g. Kitchen, Roof - North Side", text: $name)
                }

                Section("Folder Type") {
                    Picker("Type", selection: $folderType) {
                        ForEach(FolderType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if folderType == .phase {
                    Section("Quick Add") {
                        ForEach(FolderType.presetPhases, id: \.self) { phase in
                            Button {
                                name = phase
                            } label: {
                                Text(phase)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createFolder()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func createFolder() {
        let folder = Folder(
            name: name,
            folderType: folderType,
            sortOrder: project.folders.count,
            project: project
        )

        modelContext.insert(folder)
        project.folders.append(folder)
        project.updatedAt = Date()
        dismiss()
    }
}

struct FolderDetailView: View {
    let folder: Folder
    let project: Project
    @Environment(\.modelContext) private var modelContext

    @State private var selectedPhoto: Photo?
    @State private var isSelectionMode = false
    @State private var selectedPhotos: Set<UUID> = []
    @State private var showingDeleteConfirmation = false
    @State private var showingMoveSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if folder.photos.isEmpty {
                    emptyState
                } else {
                    photoGrid
                }
            }
            .navigationTitle(folder.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !folder.photos.isEmpty {
                        Button(isSelectionMode ? "Done" : "Select") {
                            withAnimation {
                                isSelectionMode.toggle()
                                if !isSelectionMode {
                                    selectedPhotos.removeAll()
                                }
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelectionMode && !selectedPhotos.isEmpty {
                    bulkActionBar
                }
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo, project: project)
            }
            .sheet(isPresented: $showingMoveSheet) {
                MovePhotosView(
                    project: project,
                    currentFolder: folder,
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
    }

    private var emptyState: some View {
        VStack(spacing: FVSpacing.md) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(FVColors.tertiaryLabel)

            Text("No photos in this folder")
                .font(FVTypography.subheadline)
                .foregroundStyle(FVColors.secondaryLabel)

            Text("Photos will appear here when you add them to this folder")
                .font(FVTypography.caption)
                .foregroundStyle(FVColors.tertiaryLabel)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var photoGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: Constants.UI.gridSpacing),
            GridItem(.flexible(), spacing: Constants.UI.gridSpacing),
            GridItem(.flexible(), spacing: Constants.UI.gridSpacing)
        ], spacing: Constants.UI.gridSpacing) {
            ForEach(folder.photos) { photo in
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
        for photo in folder.photos where selectedPhotos.contains(photo.id) {
            if let localPath = photo.localURL?.path {
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

struct SelectablePhotoThumbnail: View {
    let photo: Photo
    let isSelected: Bool
    let isSelectionMode: Bool
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            PhotoThumbnail(photo: photo)
                .overlay {
                    if isSelected {
                        Color.black.opacity(0.3)
                    }
                }
            
            if isSelectionMode {
                ZStack {
                    Circle()
                        .fill(isSelected ? FVColors.Fallback.primary : Color.white.opacity(0.8))
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .stroke(FVColors.secondaryLabel, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
                .padding(FVSpacing.xs)
            }
        }
    }
}

struct MovePhotosView: View {
    let project: Project
    let currentFolder: Folder
    let photoIds: Set<UUID>
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(project.folders.filter { $0.id != currentFolder.id }) { folder in
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
    
    private func movePhotos(to targetFolder: Folder) {
        for photo in currentFolder.photos where photoIds.contains(photo.id) {
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
    FolderGridView(project: Project(name: "Test", address: "123 Main St"))
}
