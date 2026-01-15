import Foundation
import SwiftData
import Network
import BackgroundTasks

@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published private(set) var isSyncing = false
    @Published private(set) var syncProgress: Double = 0
    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var lastError: SyncError?

    private let apiClient = APIClient.shared
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.fieldvision.syncmonitor")
    private var isNetworkAvailable = true
    private var modelContext: ModelContext?
    private var syncTask: Task<Void, Never>?

    private init() {
        setupNetworkMonitoring()
        loadLastSyncDate()
    }

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            await updatePendingCount()
        }
    }

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasAvailable = self?.isNetworkAvailable ?? false
                self?.isNetworkAvailable = path.status == .satisfied

                if !wasAvailable && path.status == .satisfied {
                    await self?.triggerSync()
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    private func loadLastSyncDate() {
        if let timestamp = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.lastSyncDate) as? Date {
            lastSyncDate = timestamp
        }
    }

    func triggerSync() async {
        guard !isSyncing, isNetworkAvailable, let context = modelContext else { return }

        isSyncing = true
        syncProgress = 0
        lastError = nil

        do {
            let pendingItems = try await fetchPendingItems(from: context)
            let totalItems = pendingItems.count

            guard totalItems > 0 else {
                isSyncing = false
                return
            }

            var processedCount = 0

            for item in pendingItems {
                do {
                    try await processQueueItem(item, context: context)
                    processedCount += 1
                    syncProgress = Double(processedCount) / Double(totalItems)
                } catch {
                    await handleItemFailure(item, error: error, context: context)
                }
            }

            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: Constants.UserDefaultsKeys.lastSyncDate)

        } catch {
            lastError = .fetchFailed(error.localizedDescription)
        }

        await updatePendingCount()
        isSyncing = false
        syncProgress = 1.0
    }

    private func fetchPendingItems(from context: ModelContext) async throws -> [SyncQueueItem] {
        let descriptor = FetchDescriptor<SyncQueueItem>(
            predicate: #Predicate { $0.retryCount < 3 },
            sortBy: [
                SortDescriptor(\.priority, order: .reverse),
                SortDescriptor(\.createdAt)
            ]
        )
        return try context.fetch(descriptor)
    }

    private func processQueueItem(_ item: SyncQueueItem, context: ModelContext) async throws {
        switch item.entityType {
        case .project:
            try await syncProject(item, context: context)
        case .folder:
            try await syncFolder(item, context: context)
        case .photo:
            try await syncPhoto(item, context: context)
        case .comment:
            try await syncComment(item, context: context)
        case .shareLink:
            try await syncShareLink(item, context: context)
        }

        context.delete(item)
        try context.save()
    }

    private func syncProject(_ item: SyncQueueItem, context: ModelContext) async throws {
        let entityId = item.entityId
        let descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == entityId })
        guard let project = try context.fetch(descriptor).first else {
            throw SyncError.entityNotFound
        }

        switch item.operation {
        case .create:
            let request = CreateProjectRequest(
                name: project.name,
                address: project.address,
                latitude: project.latitude,
                longitude: project.longitude,
                clientName: project.clientName,
                status: project.status.rawValue.uppercased().replacingOccurrences(of: " ", with: "_")
            )
            let response = try await apiClient.createProject(request)
            project.remoteId = response.id
            project.syncStatus = .synced

        case .update:
            guard let remoteId = project.remoteId else { throw SyncError.missingRemoteId }
            let request = UpdateProjectRequest(
                name: project.name,
                address: project.address,
                latitude: project.latitude,
                longitude: project.longitude,
                clientName: project.clientName,
                status: project.status.rawValue.uppercased().replacingOccurrences(of: " ", with: "_")
            )
            _ = try await apiClient.updateProject(id: remoteId, request)
            project.syncStatus = .synced

        case .delete:
            guard let remoteId = project.remoteId else { return }
            try await apiClient.deleteProject(id: remoteId)
        }
    }

    private func syncFolder(_ item: SyncQueueItem, context: ModelContext) async throws {
        let entityId = item.entityId
        let descriptor = FetchDescriptor<Folder>(predicate: #Predicate { $0.id == entityId })
        guard let folder = try context.fetch(descriptor).first,
              let project = folder.project,
              let projectRemoteId = project.remoteId else {
            throw SyncError.entityNotFound
        }

        switch item.operation {
        case .create:
            let request = CreateFolderRequest(
                name: folder.name,
                folderType: folder.folderType.rawValue.uppercased()
            )
            let response = try await apiClient.createFolder(projectId: projectRemoteId, request)
            folder.remoteId = response.id
            folder.syncStatus = .synced

        case .update, .delete:
            break
        }
    }

    private func syncPhoto(_ item: SyncQueueItem, context: ModelContext) async throws {
        let entityId = item.entityId
        let descriptor = FetchDescriptor<Photo>(predicate: #Predicate { $0.id == entityId })
        guard let photo = try context.fetch(descriptor).first,
              let project = photo.project,
              let projectRemoteId = project.remoteId else {
            throw SyncError.entityNotFound
        }

        switch item.operation {
        case .create:
            if photo.remoteUrl == nil {
                let localURL = URL(fileURLWithPath: photo.localPath)
                let imageData = try Data(contentsOf: localURL)

                let filename = localURL.lastPathComponent
                let contentType = photo.mediaType == .photo ? "image/jpeg" : "video/quicktime"

                let uploadInfo = try await apiClient.getUploadUrl(
                    projectId: projectRemoteId,
                    filename: filename,
                    contentType: contentType
                )

                guard let uploadURL = URL(string: uploadInfo.uploadUrl) else {
                    throw SyncError.invalidURL
                }

                try await apiClient.uploadMedia(to: uploadURL, data: imageData, contentType: contentType)

                photo.remoteUrl = uploadInfo.mediaUrl
                photo.thumbnailRemoteUrl = uploadInfo.thumbnailUrl
            }

            let request = CreatePhotoRequest(
                projectId: projectRemoteId,
                folderId: photo.folder?.remoteId,
                capturedAt: photo.capturedAt,
                latitude: photo.latitude,
                longitude: photo.longitude,
                mediaType: photo.mediaType.rawValue.uppercased(),
                remoteUrl: photo.remoteUrl!,
                thumbnailUrl: photo.thumbnailRemoteUrl,
                note: photo.note
            )

            let response = try await apiClient.createPhoto(request)
            photo.remoteId = response.id
            photo.syncStatus = .synced

        case .update, .delete:
            break
        }
    }

    private func syncComment(_ item: SyncQueueItem, context: ModelContext) async throws {
        let entityId = item.entityId
        let descriptor = FetchDescriptor<Comment>(predicate: #Predicate { $0.id == entityId })
        guard let comment = try context.fetch(descriptor).first,
              let photo = comment.photo,
              let photoRemoteId = photo.remoteId else {
            throw SyncError.entityNotFound
        }

        switch item.operation {
        case .create:
            let response = try await apiClient.createComment(photoId: photoRemoteId, text: comment.text)
            comment.remoteId = response.id
            comment.syncStatus = .synced

        case .update, .delete:
            break
        }
    }

    private func syncShareLink(_ item: SyncQueueItem, context: ModelContext) async throws {
        // Share links are created directly via API in ShareConfigView
    }

    private func handleItemFailure(_ item: SyncQueueItem, error: Error, context: ModelContext) async {
        item.retryCount += 1
        item.lastAttemptAt = Date()
        item.errorMessage = error.localizedDescription

        if item.retryCount >= Constants.Sync.maxRetryCount {
            await updateEntitySyncStatus(item, to: .failed, context: context)
        }

        try? context.save()
    }

    private func updateEntitySyncStatus(_ item: SyncQueueItem, to status: SyncStatus, context: ModelContext) async {
        let entityId = item.entityId
        switch item.entityType {
        case .project:
            let descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == entityId })
            if let entity = try? context.fetch(descriptor).first {
                entity.syncStatus = status
            }
        case .folder:
            let descriptor = FetchDescriptor<Folder>(predicate: #Predicate { $0.id == entityId })
            if let entity = try? context.fetch(descriptor).first {
                entity.syncStatus = status
            }
        case .photo:
            let descriptor = FetchDescriptor<Photo>(predicate: #Predicate { $0.id == entityId })
            if let entity = try? context.fetch(descriptor).first {
                entity.syncStatus = status
            }
        case .comment:
            let descriptor = FetchDescriptor<Comment>(predicate: #Predicate { $0.id == entityId })
            if let entity = try? context.fetch(descriptor).first {
                entity.syncStatus = status
            }
        case .shareLink:
            let descriptor = FetchDescriptor<ProjectShareLink>(predicate: #Predicate { $0.id == entityId })
            if let entity = try? context.fetch(descriptor).first {
                entity.syncStatus = status
            }
        }
    }

    func updatePendingCount() async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<SyncQueueItem>(predicate: #Predicate { $0.retryCount < 3 })
        pendingCount = (try? context.fetchCount(descriptor)) ?? 0
    }

    func addToQueue(entityType: SyncEntityType, entityId: UUID, operation: SyncOperation, priority: SyncPriority = .normal) {
        guard let context = modelContext else { return }

        let item = SyncQueueItem(
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            priority: priority
        )

        context.insert(item)
        try? context.save()

        Task {
            await updatePendingCount()
            if isNetworkAvailable {
                await triggerSync()
            }
        }
    }

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.fieldvision.sync",
            using: nil
        ) { task in
            self.handleBackgroundTask(task as! BGProcessingTask)
        }
    }

    private func handleBackgroundTask(_ task: BGProcessingTask) {
        scheduleNextBackgroundTask()

        syncTask = Task {
            await triggerSync()
            task.setTaskCompleted(success: lastError == nil)
        }

        task.expirationHandler = {
            self.syncTask?.cancel()
        }
    }

    func scheduleNextBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: "com.fieldvision.sync")
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: Constants.Sync.backgroundSyncInterval)

        try? BGTaskScheduler.shared.submit(request)
    }

    deinit {
        networkMonitor.cancel()
    }
}

enum SyncError: LocalizedError {
    case fetchFailed(String)
    case entityNotFound
    case missingRemoteId
    case invalidURL
    case uploadFailed
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Failed to fetch sync items: \(message)"
        case .entityNotFound:
            return "Entity not found in local database"
        case .missingRemoteId:
            return "Entity has not been synced to server yet"
        case .invalidURL:
            return "Invalid upload URL received"
        case .uploadFailed:
            return "Failed to upload media"
        case .networkUnavailable:
            return "Network connection unavailable"
        }
    }
}
