import SwiftUI
import SwiftData

@MainActor
final class ProjectListViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    
    private let apiClient = APIClient.shared
    
    func refreshProjects() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            _ = try await apiClient.getProjects()
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}
