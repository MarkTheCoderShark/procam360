import SwiftUI
import SwiftData
import MapKit

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]

    @StateObject private var viewModel = ProjectListViewModel()
    @State private var showingCreateProject = false
    @State private var showingGlobalSearch = false
    @State private var searchText = ""
    @State private var selectedFilter: ProjectStatus?

    var filteredProjects: [Project] {
        projects.filter { project in
            let matchesSearch = searchText.isEmpty ||
                project.name.localizedCaseInsensitiveContains(searchText) ||
                project.address.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = selectedFilter == nil || project.status == selectedFilter
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if projects.isEmpty {
                    emptyStateView
                } else {
                    projectListContent
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FVFloatingActionButton(icon: "plus") {
                            showingCreateProject = true
                        }
                        .padding(.trailing, FVSpacing.lg)
                        .padding(.bottom, FVSpacing.lg)
                    }
                }
            }
            .navigationTitle("Projects")
            .searchable(text: $searchText, prompt: "Search projects...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingGlobalSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(FVColors.Fallback.primary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            selectedFilter = nil
                        } label: {
                            Label("All Projects", systemImage: selectedFilter == nil ? "checkmark" : "")
                        }

                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            Button {
                                selectedFilter = status
                            } label: {
                                Label(status.displayName, systemImage: selectedFilter == status ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .symbolVariant(selectedFilter != nil ? .fill : .none)
                            .foregroundStyle(FVColors.Fallback.primary)
                    }
                }
            }
            .sheet(isPresented: $showingCreateProject) {
                CreateProjectView()
            }
            .sheet(isPresented: $showingGlobalSearch) {
                SearchView()
            }
            .refreshable {
                await viewModel.refreshProjects()
            }
            .navigationDestination(for: Project.self) { project in
                ProjectDetailView(project: project)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: FVSpacing.lg) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(FVColors.tertiaryLabel)

            Text("No Projects Yet")
                .font(FVTypography.title2)
                .foregroundStyle(FVColors.label)

            Text("Create your first project to start\ncapturing job site photos")
                .font(FVTypography.body)
                .foregroundStyle(FVColors.secondaryLabel)
                .multilineTextAlignment(.center)

            FVPrimaryButton(title: "Create Project") {
                showingCreateProject = true
            }
            .frame(width: 200)
        }
        .padding()
    }

    private var projectListContent: some View {
        ScrollView {
            LazyVStack(spacing: FVSpacing.sm) {
                ForEach(filteredProjects) { project in
                    NavigationLink(value: project) {
                        ProjectCard(project: project)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, FVSpacing.sm)
            .padding(.bottom, 100)
        }
    }
}

struct ProjectCard: View {
    let project: Project

    var body: some View {
        HStack(spacing: FVSpacing.md) {
            projectThumbnail

            VStack(alignment: .leading, spacing: FVSpacing.xxs) {
                HStack {
                    Text(project.name)
                        .font(FVTypography.headline)
                        .foregroundStyle(FVColors.label)
                        .lineLimit(1)

                    Spacer()

                    statusBadge
                }

                Text(project.address)
                    .font(FVTypography.subheadline)
                    .foregroundStyle(FVColors.secondaryLabel)
                    .lineLimit(1)

                HStack(spacing: FVSpacing.md) {
                    Label("\(project.photoCount)", systemImage: "photo")
                    Label("\(project.folderCount)", systemImage: "folder")
                }
                .font(FVTypography.caption)
                .foregroundStyle(FVColors.tertiaryLabel)
            }
        }
        .padding(FVSpacing.md)
        .background(FVColors.secondaryBackground)
        .cornerRadius(FVRadius.md)
    }

    private var projectThumbnail: some View {
        Group {
            if let coverPhoto = project.photos.first,
               let thumbnailURL = coverPhoto.thumbnailURL {
                AsyncImage(url: thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    thumbnailPlaceholder
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: FVRadius.sm))
    }

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(FVColors.tertiaryBackground)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(FVColors.tertiaryLabel)
            }
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
}

// MARK: - Project Map Tab (with Navigation)

struct ProjectMapTab: View {
    @State private var showingCreateProject = false

    var body: some View {
        NavigationStack {
            ZStack {
                ProjectMapView()

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FVFloatingActionButton(icon: "plus") {
                            showingCreateProject = true
                        }
                        .padding(.trailing, FVSpacing.lg)
                        .padding(.bottom, FVSpacing.lg)
                    }
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingCreateProject) {
                CreateProjectView()
            }
            .navigationDestination(for: Project.self) { project in
                ProjectDetailView(project: project)
            }
        }
    }
}

// MARK: - Project Map View

struct ProjectMapView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedProject: Project?

    private var projectsWithLocation: [Project] {
        projects.filter { $0.hasLocation }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position, selection: $selectedProject) {
                ForEach(projectsWithLocation) { project in
                    Annotation(project.name, coordinate: CLLocationCoordinate2D(
                        latitude: project.latitude ?? 0,
                        longitude: project.longitude ?? 0
                    )) {
                        ProjectMapPin(project: project, isSelected: selectedProject?.id == project.id)
                    }
                    .tag(project)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapUserLocationButton()
                MapScaleView()
            }

            if let project = selectedProject {
                selectedProjectCard(project: project)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: selectedProject)
        .onAppear {
            centerOnProjects()
        }
    }

    private func centerOnProjects() {
        guard !projectsWithLocation.isEmpty else { return }

        if projectsWithLocation.count == 1,
           let project = projectsWithLocation.first,
           let lat = project.latitude,
           let lon = project.longitude {
            position = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        } else {
            let lats = projectsWithLocation.compactMap { $0.latitude }
            let lons = projectsWithLocation.compactMap { $0.longitude }

            guard let minLat = lats.min(),
                  let maxLat = lats.max(),
                  let minLon = lons.min(),
                  let maxLon = lons.max() else { return }

            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )

            let span = MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.5, 0.05),
                longitudeDelta: max((maxLon - minLon) * 1.5, 0.05)
            )

            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    private func selectedProjectCard(project: Project) -> some View {
        NavigationLink(value: project) {
            HStack(spacing: FVSpacing.md) {
                mapProjectThumbnail(project: project)

                VStack(alignment: .leading, spacing: FVSpacing.xxs) {
                    HStack {
                        Text(project.name)
                            .font(FVTypography.headline)
                            .foregroundStyle(FVColors.label)
                            .lineLimit(1)

                        Spacer()

                        mapStatusBadge(project: project)
                    }

                    Text(project.address)
                        .font(FVTypography.subheadline)
                        .foregroundStyle(FVColors.secondaryLabel)
                        .lineLimit(1)

                    HStack(spacing: FVSpacing.md) {
                        Label("\(project.photoCount)", systemImage: "photo")
                        Label("\(project.folderCount)", systemImage: "folder")
                    }
                    .font(FVTypography.caption)
                    .foregroundStyle(FVColors.tertiaryLabel)
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(FVColors.tertiaryLabel)
            }
            .padding(FVSpacing.md)
            .background(FVColors.secondaryBackground)
            .cornerRadius(FVRadius.lg)
        }
        .buttonStyle(.plain)
        .padding()
        .background(.ultraThinMaterial)
    }

    private func mapProjectThumbnail(project: Project) -> some View {
        Group {
            if let coverPhoto = project.photos.first,
               let thumbnailURL = coverPhoto.thumbnailURL {
                AsyncImage(url: thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    mapThumbnailPlaceholder
                }
            } else {
                mapThumbnailPlaceholder
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: FVRadius.sm))
    }

    private var mapThumbnailPlaceholder: some View {
        Rectangle()
            .fill(FVColors.tertiaryBackground)
            .overlay {
                Image(systemName: "building.2")
                    .foregroundStyle(FVColors.tertiaryLabel)
            }
    }

    private func mapStatusBadge(project: Project) -> some View {
        Text(project.status.displayName)
            .font(FVTypography.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, FVSpacing.xs)
            .padding(.vertical, FVSpacing.xxxs)
            .background(mapStatusColor(for: project).opacity(0.15))
            .foregroundStyle(mapStatusColor(for: project))
            .cornerRadius(FVRadius.xs)
    }

    private func mapStatusColor(for project: Project) -> Color {
        switch project.status {
        case .walkthrough: return FVColors.statusWalkthrough
        case .inProgress: return FVColors.statusInProgress
        case .completed: return FVColors.statusCompleted
        }
    }
}

struct ProjectMapPin: View {
    let project: Project
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(pinColor)
                    .frame(width: isSelected ? 50 : 40, height: isSelected ? 50 : 40)
                    .shadow(color: pinColor.opacity(0.4), radius: isSelected ? 8 : 4)

                Image(systemName: "building.2.fill")
                    .font(.system(size: isSelected ? 22 : 18))
                    .foregroundStyle(.white)
            }

            Triangle()
                .fill(pinColor)
                .frame(width: 12, height: 8)
                .offset(y: -2)
        }
        .animation(.spring(duration: 0.3), value: isSelected)
    }

    private var pinColor: Color {
        switch project.status {
        case .walkthrough: return FVColors.statusWalkthrough
        case .inProgress: return FVColors.statusInProgress
        case .completed: return FVColors.statusCompleted
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ProjectListView()
        .modelContainer(for: Project.self, inMemory: true)
}
