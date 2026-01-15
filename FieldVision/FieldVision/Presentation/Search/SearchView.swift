import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var selectedSegment: SearchSegment = .all
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Search Type", selection: $selectedSegment) {
                    ForEach(SearchSegment.allCases, id: \.self) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, FVSpacing.sm)
                
                if viewModel.isSearching {
                    loadingView
                } else if searchText.isEmpty {
                    emptySearchView
                } else if viewModel.projects.isEmpty && viewModel.photos.isEmpty {
                    noResultsView
                } else {
                    searchResultsList
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search projects, notes, transcriptions...")
            .onChange(of: searchText) { _, newValue in
                viewModel.search(query: newValue, type: selectedSegment.apiValue)
            }
            .onChange(of: selectedSegment) { _, _ in
                if !searchText.isEmpty {
                    viewModel.search(query: searchText, type: selectedSegment.apiValue)
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching...")
                .font(FVTypography.caption)
                .foregroundStyle(FVColors.secondaryLabel)
                .padding(.top, FVSpacing.sm)
            Spacer()
        }
    }
    
    private var emptySearchView: some View {
        VStack(spacing: FVSpacing.lg) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(FVColors.tertiaryLabel)
            
            Text("Search Your Projects")
                .font(FVTypography.title2)
                .foregroundStyle(FVColors.label)
            
            Text("Find projects by name, address, or search\nphoto notes and voice transcriptions")
                .font(FVTypography.body)
                .foregroundStyle(FVColors.secondaryLabel)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
    
    private var noResultsView: some View {
        VStack(spacing: FVSpacing.md) {
            Spacer()
            
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(FVColors.tertiaryLabel)
            
            Text("No Results")
                .font(FVTypography.headline)
                .foregroundStyle(FVColors.label)
            
            Text("No matches found for \"\(searchText)\"")
                .font(FVTypography.subheadline)
                .foregroundStyle(FVColors.secondaryLabel)
            
            Spacer()
        }
    }
    
    private var searchResultsList: some View {
        List {
            if !viewModel.projects.isEmpty && (selectedSegment == .all || selectedSegment == .projects) {
                Section {
                    ForEach(viewModel.projects) { project in
                        NavigationLink {
                            ProjectDetailFromSearchView(projectId: project.id)
                        } label: {
                            SearchProjectRow(project: project, searchTerm: searchText)
                        }
                    }
                    
                    if viewModel.hasMoreProjects && selectedSegment == .projects {
                        Button {
                            viewModel.loadMoreProjects(query: searchText)
                        } label: {
                            HStack {
                                Spacer()
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                } else {
                                    Text("Load More")
                                }
                                Spacer()
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Projects")
                        Spacer()
                        Text("\(viewModel.totalProjects) found")
                            .font(FVTypography.caption)
                            .foregroundStyle(FVColors.tertiaryLabel)
                    }
                }
            }
            
            if !viewModel.photos.isEmpty && (selectedSegment == .all || selectedSegment == .photos) {
                Section {
                    ForEach(viewModel.photos) { photo in
                        SearchPhotoRow(photo: photo, searchTerm: searchText)
                    }
                    
                    if viewModel.hasMorePhotos && selectedSegment == .photos {
                        Button {
                            viewModel.loadMorePhotos(query: searchText)
                        } label: {
                            HStack {
                                Spacer()
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                } else {
                                    Text("Load More")
                                }
                                Spacer()
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Photos")
                        Spacer()
                        Text("\(viewModel.totalPhotos) found")
                            .font(FVTypography.caption)
                            .foregroundStyle(FVColors.tertiaryLabel)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct SearchProjectRow: View {
    let project: SearchProjectResult
    let searchTerm: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: FVSpacing.xxs) {
            Text(project.name)
                .font(FVTypography.headline)
                .foregroundStyle(FVColors.label)
            
            Text(project.address)
                .font(FVTypography.subheadline)
                .foregroundStyle(FVColors.secondaryLabel)
                .lineLimit(1)
            
            HStack(spacing: FVSpacing.md) {
                Label("\(project.photoCount)", systemImage: "photo")
                Label("\(project.folderCount)", systemImage: "folder")
                
                Spacer()
                
                Text(project.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(FVTypography.caption2)
                    .padding(.horizontal, FVSpacing.xs)
                    .padding(.vertical, FVSpacing.xxxs)
                    .background(statusColor.opacity(0.15))
                    .foregroundStyle(statusColor)
                    .cornerRadius(FVRadius.xs)
            }
            .font(FVTypography.caption)
            .foregroundStyle(FVColors.tertiaryLabel)
        }
        .padding(.vertical, FVSpacing.xxs)
    }
    
    private var statusColor: Color {
        switch project.status {
        case "WALKTHROUGH": return FVColors.statusWalkthrough
        case "IN_PROGRESS": return FVColors.statusInProgress
        case "COMPLETED": return FVColors.statusCompleted
        default: return FVColors.secondaryLabel
        }
    }
}

struct SearchPhotoRow: View {
    let photo: SearchPhotoResult
    let searchTerm: String
    
    var body: some View {
        HStack(spacing: FVSpacing.md) {
            if let thumbnailUrl = photo.thumbnailUrl, let url = URL(string: thumbnailUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(FVColors.tertiaryBackground)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(FVColors.tertiaryLabel)
                        }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: FVRadius.sm))
            } else {
                Rectangle()
                    .fill(FVColors.tertiaryBackground)
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: photo.mediaType == "VIDEO" ? "video" : "photo")
                            .foregroundStyle(FVColors.tertiaryLabel)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: FVRadius.sm))
            }
            
            VStack(alignment: .leading, spacing: FVSpacing.xxxs) {
                Text(photo.projectName)
                    .font(FVTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(FVColors.label)
                
                if let note = photo.note ?? photo.voiceNoteTranscription {
                    Text(note)
                        .font(FVTypography.caption)
                        .foregroundStyle(FVColors.secondaryLabel)
                        .lineLimit(2)
                }
                
                HStack {
                    Text(photo.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    Text("•")
                    Text(photo.uploaderName)
                }
                .font(FVTypography.caption2)
                .foregroundStyle(FVColors.tertiaryLabel)
            }
        }
        .padding(.vertical, FVSpacing.xxs)
    }
}

struct ProjectDetailFromSearchView: View {
    let projectId: String
    @Query private var projects: [Project]
    
    init(projectId: String) {
        self.projectId = projectId
        let uuid = UUID(uuidString: projectId) ?? UUID()
        _projects = Query(filter: #Predicate<Project> { $0.remoteId == projectId || $0.id == uuid })
    }
    
    var body: some View {
        if let project = projects.first {
            ProjectDetailView(project: project)
        } else {
            VStack {
                ProgressView()
                Text("Loading project...")
                    .font(FVTypography.caption)
                    .foregroundStyle(FVColors.secondaryLabel)
            }
        }
    }
}

enum SearchSegment: CaseIterable {
    case all
    case projects
    case photos
    
    var title: String {
        switch self {
        case .all: return "All"
        case .projects: return "Projects"
        case .photos: return "Photos"
        }
    }
    
    var apiValue: String {
        switch self {
        case .all: return "all"
        case .projects: return "projects"
        case .photos: return "photos"
        }
    }
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var projects: [SearchProjectResult] = []
    @Published var photos: [SearchPhotoResult] = []
    @Published var isSearching = false
    @Published var isLoadingMore = false
    @Published var hasMoreProjects = false
    @Published var hasMorePhotos = false
    @Published var totalProjects = 0
    @Published var totalPhotos = 0
    
    private let apiClient = APIClient.shared
    private var currentPage = 1
    private var searchTask: Task<Void, Never>?
    
    func search(query: String, type: String) {
        searchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            projects = []
            photos = []
            return
        }
        
        searchTask = Task {
            isSearching = true
            currentPage = 1
            
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                
                guard !Task.isCancelled else { return }
                
                let response = try await apiClient.search(query: query, type: type)
                
                guard !Task.isCancelled else { return }
                
                projects = response.projects
                photos = response.photos
                totalProjects = response.totalProjects
                totalPhotos = response.totalPhotos
                hasMoreProjects = response.hasMoreProjects
                hasMorePhotos = response.hasMorePhotos
            } catch {
                if !Task.isCancelled {
                    projects = []
                    photos = []
                }
            }
            
            isSearching = false
        }
    }
    
    func loadMoreProjects(query: String) {
        guard !isLoadingMore, hasMoreProjects else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        Task {
            do {
                let response = try await apiClient.search(query: query, type: "projects", page: currentPage)
                projects.append(contentsOf: response.projects)
                hasMoreProjects = response.hasMoreProjects
            } catch {
                currentPage -= 1
            }
            isLoadingMore = false
        }
    }
    
    func loadMorePhotos(query: String) {
        guard !isLoadingMore, hasMorePhotos else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        Task {
            do {
                let response = try await apiClient.search(query: query, type: "photos", page: currentPage)
                photos.append(contentsOf: response.photos)
                hasMorePhotos = response.hasMorePhotos
            } catch {
                currentPage -= 1
            }
            isLoadingMore = false
        }
    }
}

#Preview {
    SearchView()
}
