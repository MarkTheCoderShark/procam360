import SwiftUI
import SwiftData

struct ReportConfigView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    
    @State private var configuration = ReportConfiguration()
    @State private var selectedFolders: Set<UUID> = []
    @State private var selectAllFolders = true
    @State private var isGenerating = false
    @State private var generationProgress: Double = 0
    @State private var generatedReportURL: URL?
    @State private var showingShareSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var useDateFilter = false
    @State private var startDate = Date().addingTimeInterval(-30 * 24 * 60 * 60)
    @State private var endDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                contentSection
                folderSelectionSection
                dateFilterSection
                layoutSection
                optionalSections
            }
            .navigationTitle("Generate Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        generateReport()
                    }
                    .fontWeight(.semibold)
                    .disabled(isGenerating || effectivePhotoCount == 0)
                }
            }
            .overlay {
                if isGenerating {
                    generatingOverlay
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = generatedReportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                selectedFolders = Set(project.folders.map { $0.id })
            }
        }
    }
    
    private var contentSection: some View {
        Section {
            Toggle("Include Notes", isOn: $configuration.includeNotes)
            Toggle("Include Voice Transcriptions", isOn: $configuration.includeTranscriptions)
            Toggle("Include Timestamps", isOn: $configuration.includeTimestamps)
            Toggle("Include Location Data", isOn: $configuration.includeLocation)
        } header: {
            Text("Photo Details")
        }
    }
    
    private var folderSelectionSection: some View {
        Section {
            Toggle("All Folders", isOn: $selectAllFolders)
                .onChange(of: selectAllFolders) { _, newValue in
                    if newValue {
                        selectedFolders = Set(project.folders.map { $0.id })
                    }
                }
            
            if !selectAllFolders {
                ForEach(project.folders.sorted(by: { $0.sortOrder < $1.sortOrder })) { folder in
                    HStack {
                        Image(systemName: folder.folderType.iconName)
                            .foregroundStyle(FVColors.Fallback.primary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading) {
                            Text(folder.name)
                            Text("\(folder.photoCount) photos")
                                .font(FVTypography.caption)
                                .foregroundStyle(FVColors.secondaryLabel)
                        }
                        
                        Spacer()
                        
                        if selectedFolders.contains(folder.id) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(FVColors.Fallback.primary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleFolder(folder.id)
                    }
                }
            }
        } header: {
            Text("Folders")
        } footer: {
            Text("\(effectivePhotoCount) photos will be included")
        }
    }
    
    private var dateFilterSection: some View {
        Section {
            Toggle("Filter by Date", isOn: $useDateFilter)
            
            if useDateFilter {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                DatePicker("To", selection: $endDate, displayedComponents: .date)
            }
        } header: {
            Text("Date Range")
        }
    }
    
    private var layoutSection: some View {
        Section {
            Picker("Photos per Page", selection: $configuration.photosPerPage) {
                ForEach(ReportConfiguration.PhotosPerPage.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            
            Toggle("Include Cover Page", isOn: $configuration.includeCoverPage)
            Toggle("Include Table of Contents", isOn: $configuration.includeTableOfContents)
            Toggle("Include Project Summary", isOn: $configuration.includeProjectSummary)
        } header: {
            Text("Layout")
        }
    }
    
    private var optionalSections: some View {
        Section {
            TextField("Company Name (Optional)", text: Binding(
                get: { configuration.companyName ?? "" },
                set: { configuration.companyName = $0.isEmpty ? nil : $0 }
            ))
        } header: {
            Text("Branding")
        } footer: {
            Text("Add your company name to the cover page")
        }
    }
    
    private var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: FVSpacing.md) {
                ProgressView(value: generationProgress)
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .tint(FVColors.Fallback.primary)
                
                Text("Generating Report...")
                    .font(FVTypography.headline)
                    .foregroundStyle(.white)
                
                Text("\(Int(generationProgress * 100))%")
                    .font(FVTypography.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(FVSpacing.xl)
            .background(.ultraThinMaterial)
            .cornerRadius(FVRadius.lg)
        }
    }
    
    private var effectivePhotoCount: Int {
        var photos = project.photos
        
        if !selectAllFolders {
            photos = photos.filter { photo in
                guard let folderId = photo.folder?.id else { return false }
                return selectedFolders.contains(folderId)
            }
        }
        
        if useDateFilter {
            photos = photos.filter { startDate...endDate ~= $0.capturedAt }
        }
        
        return photos.count
    }
    
    private func toggleFolder(_ id: UUID) {
        if selectedFolders.contains(id) {
            selectedFolders.remove(id)
        } else {
            selectedFolders.insert(id)
        }
        
        selectAllFolders = selectedFolders.count == project.folders.count
    }
    
    private func generateReport() {
        isGenerating = true
        generationProgress = 0
        
        var config = configuration
        
        if !selectAllFolders {
            config.selectedFolderIds = selectedFolders
        }
        
        if useDateFilter {
            config.dateRange = startDate...endDate
        }
        
        Task {
            do {
                let url = try await ReportGeneratorService.shared.generateReport(
                    for: project,
                    configuration: config,
                    progress: { progress in
                        Task { @MainActor in
                            generationProgress = progress
                        }
                    }
                )
                
                await MainActor.run {
                    isGenerating = false
                    generatedReportURL = url
                    showingShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SavedReportsView: View {
    @State private var reports: [URL] = []
    @State private var selectedReport: URL?
    @State private var showingShareSheet = false
    
    var body: some View {
        List {
            if reports.isEmpty {
                ContentUnavailableView(
                    "No Reports",
                    systemImage: "doc.text",
                    description: Text("Generated reports will appear here")
                )
            } else {
                ForEach(reports, id: \.self) { url in
                    Button {
                        selectedReport = url
                        showingShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.richtext")
                                .foregroundStyle(FVColors.Fallback.primary)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: FVSpacing.xxxs) {
                                Text(url.deletingPathExtension().lastPathComponent)
                                    .foregroundStyle(FVColors.label)
                                
                                if let date = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(FVTypography.caption)
                                        .foregroundStyle(FVColors.secondaryLabel)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(FVColors.tertiaryLabel)
                        }
                    }
                }
                .onDelete(perform: deleteReports)
            }
        }
        .navigationTitle("Saved Reports")
        .onAppear {
            loadReports()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = selectedReport {
                ShareSheet(items: [url])
            }
        }
    }
    
    private func loadReports() {
        reports = ReportGeneratorService.shared.getSavedReports()
    }
    
    private func deleteReports(at offsets: IndexSet) {
        for index in offsets {
            try? ReportGeneratorService.shared.deleteReport(at: reports[index])
        }
        reports.remove(atOffsets: offsets)
    }
}

#Preview {
    ReportConfigView(project: Project(name: "Test Project", address: "123 Main St"))
        .modelContainer(for: Project.self, inMemory: true)
}
