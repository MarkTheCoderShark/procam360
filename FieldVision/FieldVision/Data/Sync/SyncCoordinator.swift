import Foundation
import SwiftData

@MainActor
final class SyncCoordinator {
    static let shared = SyncCoordinator()
    
    private let syncEngine = SyncEngine.shared
    
    private init() {}
    
    func configure(with modelContext: ModelContext) {
        syncEngine.configure(with: modelContext)
    }
    
    func projectCreated(_ project: Project) {
        syncEngine.addToQueue(
            entityType: .project,
            entityId: project.id,
            operation: .create,
            priority: .normal
        )
    }
    
    func projectUpdated(_ project: Project) {
        project.syncStatus = .pending
        syncEngine.addToQueue(
            entityType: .project,
            entityId: project.id,
            operation: .update,
            priority: .normal
        )
    }
    
    func projectDeleted(_ project: Project) {
        syncEngine.addToQueue(
            entityType: .project,
            entityId: project.id,
            operation: .delete,
            priority: .high
        )
    }
    
    func folderCreated(_ folder: Folder) {
        syncEngine.addToQueue(
            entityType: .folder,
            entityId: folder.id,
            operation: .create,
            priority: .normal
        )
    }
    
    func photoCreated(_ photo: Photo) {
        syncEngine.addToQueue(
            entityType: .photo,
            entityId: photo.id,
            operation: .create,
            priority: .high
        )
    }
    
    func photoUpdated(_ photo: Photo) {
        photo.syncStatus = .pending
        syncEngine.addToQueue(
            entityType: .photo,
            entityId: photo.id,
            operation: .update,
            priority: .normal
        )
    }
    
    func commentCreated(_ comment: Comment) {
        syncEngine.addToQueue(
            entityType: .comment,
            entityId: comment.id,
            operation: .create,
            priority: .normal
        )
    }
    
    func triggerManualSync() async {
        await syncEngine.triggerSync()
    }
}
