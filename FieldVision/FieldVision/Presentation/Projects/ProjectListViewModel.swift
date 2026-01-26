import SwiftUI
import SwiftData

@MainActor
final class ProjectListViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?

    private let apiClient = APIClient.shared

    func refreshProjects(modelContext: ModelContext) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let remoteProjects = try await apiClient.getProjects()

            // Get all existing local projects with remote IDs
            let projectDescriptor = FetchDescriptor<Project>()
            let localProjects = try modelContext.fetch(projectDescriptor)
            let localProjectsByRemoteId = Dictionary(
                uniqueKeysWithValues: localProjects.compactMap { project in
                    project.remoteId.map { ($0, project) }
                }
            )

            // Track which remote IDs we've seen
            var seenRemoteIds = Set<String>()

            for remoteProject in remoteProjects {
                seenRemoteIds.insert(remoteProject.id)

                let localProject: Project
                if let existingProject = localProjectsByRemoteId[remoteProject.id] {
                    // Update existing project
                    existingProject.name = remoteProject.name
                    existingProject.address = remoteProject.address
                    existingProject.latitude = remoteProject.latitude
                    existingProject.longitude = remoteProject.longitude
                    existingProject.clientName = remoteProject.clientName
                    existingProject.status = projectStatus(from: remoteProject.status)
                    existingProject.updatedAt = remoteProject.updatedAt
                    existingProject.syncStatus = .synced
                    localProject = existingProject
                } else {
                    // Create new local project
                    let newProject = Project(
                        name: remoteProject.name,
                        address: remoteProject.address,
                        latitude: remoteProject.latitude,
                        longitude: remoteProject.longitude,
                        clientName: remoteProject.clientName,
                        status: projectStatus(from: remoteProject.status),
                        createdAt: remoteProject.createdAt,
                        updatedAt: remoteProject.updatedAt,
                        syncStatus: .synced,
                        remoteId: remoteProject.id
                    )
                    modelContext.insert(newProject)
                    localProject = newProject
                }

                // Sync folders for this project
                if let remoteFolders = remoteProject.folders {
                    await syncFolders(remoteFolders, for: localProject, modelContext: modelContext)
                }

                // Fetch and sync photos for this project
                await syncPhotos(for: remoteProject.id, localProject: localProject, modelContext: modelContext)
            }

            // Remove local projects that no longer exist on server
            // (only if they were synced - don't delete unsynced local projects)
            for localProject in localProjects {
                if let remoteId = localProject.remoteId,
                   !seenRemoteIds.contains(remoteId),
                   localProject.syncStatus == .synced {
                    modelContext.delete(localProject)
                }
            }

            try modelContext.save()

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func syncFolders(_ remoteFolders: [FolderDTO], for project: Project, modelContext: ModelContext) async {
        let existingFoldersByRemoteId = Dictionary(
            uniqueKeysWithValues: project.folders.compactMap { folder in
                folder.remoteId.map { ($0, folder) }
            }
        )

        for remoteFolder in remoteFolders {
            if let existingFolder = existingFoldersByRemoteId[remoteFolder.id] {
                // Update existing folder
                existingFolder.name = remoteFolder.name
                existingFolder.folderType = folderType(from: remoteFolder.folderType)
                existingFolder.sortOrder = remoteFolder.sortOrder
                existingFolder.syncStatus = .synced
            } else {
                // Create new folder
                let newFolder = Folder(
                    name: remoteFolder.name,
                    folderType: folderType(from: remoteFolder.folderType),
                    sortOrder: remoteFolder.sortOrder,
                    syncStatus: .synced,
                    remoteId: remoteFolder.id,
                    project: project
                )
                modelContext.insert(newFolder)
            }
        }
    }

    private func syncPhotos(for projectRemoteId: String, localProject: Project, modelContext: ModelContext) async {
        do {
            let response = try await apiClient.getPhotos(projectId: projectRemoteId, page: 1, limit: 500)

            // Get existing photos for this project by remote ID
            let existingPhotosByRemoteId = Dictionary(
                uniqueKeysWithValues: localProject.photos.compactMap { photo in
                    photo.remoteId.map { ($0, photo) }
                }
            )

            // Get folders by remote ID for linking
            let foldersByRemoteId = Dictionary(
                uniqueKeysWithValues: localProject.folders.compactMap { folder in
                    folder.remoteId.map { ($0, folder) }
                }
            )

            for remotePhoto in response.data {
                if let existingPhoto = existingPhotosByRemoteId[remotePhoto.id] {
                    // Update existing photo
                    existingPhoto.note = remotePhoto.note
                    existingPhoto.voiceNoteRemoteUrl = remotePhoto.voiceNoteUrl
                    existingPhoto.voiceNoteTranscription = remotePhoto.voiceNoteTranscription
                    existingPhoto.syncStatus = .synced

                    // Update folder link
                    if let folderId = remotePhoto.folderId {
                        existingPhoto.folder = foldersByRemoteId[folderId]
                    }
                } else {
                    // Create new local photo from server data
                    let newPhoto = Photo(
                        uploaderId: UUID(), // We don't have the uploader UUID, use placeholder
                        uploaderName: remotePhoto.uploaderName,
                        capturedAt: remotePhoto.capturedAt,
                        latitude: remotePhoto.latitude,
                        longitude: remotePhoto.longitude,
                        mediaType: mediaType(from: remotePhoto.mediaType),
                        localPath: "", // No local file yet - will display from remote URL
                        remoteUrl: remotePhoto.remoteUrl,
                        thumbnailRemoteUrl: remotePhoto.thumbnailUrl,
                        note: remotePhoto.note,
                        voiceNoteRemoteUrl: remotePhoto.voiceNoteUrl,
                        voiceNoteTranscription: remotePhoto.voiceNoteTranscription,
                        syncStatus: .synced,
                        remoteId: remotePhoto.id,
                        createdAt: remotePhoto.createdAt,
                        updatedAt: remotePhoto.updatedAt,
                        project: localProject,
                        folder: remotePhoto.folderId.flatMap { foldersByRemoteId[$0] }
                    )
                    modelContext.insert(newPhoto)
                }
            }
        } catch {
            print("Failed to sync photos for project \(projectRemoteId): \(error)")
        }
    }

    private func projectStatus(from string: String) -> ProjectStatus {
        switch string.uppercased() {
        case "WALKTHROUGH":
            return .walkthrough
        case "IN_PROGRESS":
            return .inProgress
        case "COMPLETED":
            return .completed
        default:
            return .walkthrough
        }
    }

    private func folderType(from string: String) -> FolderType {
        switch string.uppercased() {
        case "LOCATION":
            return .location
        case "PHASE":
            return .phase
        case "CUSTOM":
            return .custom
        default:
            return .custom
        }
    }

    private func mediaType(from string: String) -> MediaType {
        switch string.uppercased() {
        case "PHOTO":
            return .photo
        case "VIDEO":
            return .video
        default:
            return .photo
        }
    }
}
