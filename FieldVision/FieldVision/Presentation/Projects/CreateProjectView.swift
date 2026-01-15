import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var viewModel = CreateProjectViewModel()
    @State private var showingTemplates = false
    @State private var selectedTemplate: ProjectTemplate?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingTemplates = true
                    } label: {
                        HStack {
                            if let template = selectedTemplate {
                                Image(systemName: template.icon)
                                    .foregroundStyle(FVColors.Fallback.primary)
                                    .frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text(template.name)
                                        .foregroundStyle(FVColors.label)
                                    Text("\(template.folders.count) folders")
                                        .font(FVTypography.caption)
                                        .foregroundStyle(FVColors.secondaryLabel)
                                }
                            } else {
                                Image(systemName: "doc.badge.plus")
                                    .foregroundStyle(FVColors.tertiaryLabel)
                                    .frame(width: 24)
                                Text("Choose Template (Optional)")
                                    .foregroundStyle(FVColors.secondaryLabel)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(FVColors.tertiaryLabel)
                        }
                    }
                } header: {
                    Text("Template")
                } footer: {
                    Text("Templates pre-create folders for common project types")
                }
                
                Section {
                    TextField("Project Name", text: $viewModel.name)
                        .textContentType(.organizationName)
                    
                    TextField("Client Name (Optional)", text: $viewModel.clientName)
                        .textContentType(.name)
                }
                
                Section {
                    AddressSearchField(
                        address: $viewModel.address,
                        coordinate: $viewModel.coordinate
                    )
                    
                    if viewModel.coordinate != nil {
                        Map(position: .constant(.automatic)) {
                            if let coord = viewModel.coordinate {
                                Marker(viewModel.address, coordinate: coord)
                            }
                        }
                        .frame(height: 150)
                        .cornerRadius(FVRadius.sm)
                        .listRowInsets(EdgeInsets(top: FVSpacing.sm, leading: 0, bottom: FVSpacing.sm, trailing: 0))
                    }
                }
                
                Section("Status") {
                    Picker("Status", selection: $viewModel.status) {
                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            Label(status.displayName, systemImage: status.iconName)
                                .tag(status)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(!viewModel.isValid)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingTemplates) {
                TemplatePickerView(selectedTemplate: $selectedTemplate)
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }
    
    private func createProject() {
        let project = Project(
            name: viewModel.name,
            address: viewModel.address,
            latitude: viewModel.coordinate?.latitude,
            longitude: viewModel.coordinate?.longitude,
            clientName: viewModel.clientName.isEmpty ? nil : viewModel.clientName,
            status: viewModel.status
        )
        
        modelContext.insert(project)
        
        if let template = selectedTemplate {
            for (index, folderDef) in template.folders.enumerated() {
                let folder = Folder(
                    name: folderDef.name,
                    folderType: folderDef.type.folderType,
                    sortOrder: index,
                    project: project
                )
                modelContext.insert(folder)
            }
        }
        
        Task {
            await viewModel.syncProject(project)
        }
        
        dismiss()
    }
}

struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTemplate: ProjectTemplate?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedTemplate = nil
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                                .foregroundStyle(FVColors.tertiaryLabel)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: FVSpacing.xxxs) {
                                Text("Blank Project")
                                    .foregroundStyle(FVColors.label)
                                Text("Start with no folders")
                                    .font(FVTypography.caption)
                                    .foregroundStyle(FVColors.secondaryLabel)
                            }
                            
                            Spacer()
                            
                            if selectedTemplate == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(FVColors.Fallback.primary)
                            }
                        }
                    }
                }
                
                Section("Industry Templates") {
                    ForEach(ProjectTemplate.builtInTemplates) { template in
                        Button {
                            selectedTemplate = template
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: template.icon)
                                    .foregroundStyle(FVColors.Fallback.primary)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: FVSpacing.xxxs) {
                                    Text(template.name)
                                        .foregroundStyle(FVColors.label)
                                    Text(template.description)
                                        .font(FVTypography.caption)
                                        .foregroundStyle(FVColors.secondaryLabel)
                                        .lineLimit(2)
                                    Text("\(template.folders.count) folders")
                                        .font(FVTypography.caption2)
                                        .foregroundStyle(FVColors.tertiaryLabel)
                                }
                                
                                Spacer()
                                
                                if selectedTemplate?.id == template.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(FVColors.Fallback.primary)
                                }
                            }
                            .padding(.vertical, FVSpacing.xxs)
                        }
                    }
                }
            }
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddressSearchField: View {
    @Binding var address: String
    @Binding var coordinate: CLLocationCoordinate2D?
    
    @StateObject private var searchCompleter = AddressSearchCompleter()
    @State private var isShowingResults = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "mappin.circle")
                    .foregroundStyle(FVColors.tertiaryLabel)
                
                TextField("Address", text: $address)
                    .textContentType(.fullStreetAddress)
                    .focused($isFocused)
                    .onChange(of: address) { _, newValue in
                        searchCompleter.search(query: newValue)
                        isShowingResults = !newValue.isEmpty && isFocused
                    }
                    .onChange(of: isFocused) { _, focused in
                        isShowingResults = focused && !address.isEmpty
                    }
                
                if !address.isEmpty {
                    Button {
                        address = ""
                        coordinate = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(FVColors.tertiaryLabel)
                    }
                }
            }
            
            if isShowingResults && !searchCompleter.results.isEmpty {
                Divider()
                    .padding(.top, FVSpacing.xs)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(searchCompleter.results, id: \.self) { result in
                            Button {
                                selectResult(result)
                            } label: {
                                VStack(alignment: .leading, spacing: FVSpacing.xxxs) {
                                    Text(result.title)
                                        .font(FVTypography.subheadline)
                                        .foregroundStyle(FVColors.label)
                                    
                                    Text(result.subtitle)
                                        .font(FVTypography.caption)
                                        .foregroundStyle(FVColors.secondaryLabel)
                                }
                                .padding(.vertical, FVSpacing.xs)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            if result != searchCompleter.results.last {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
    
    private func selectResult(_ result: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        Task {
            do {
                let response = try await search.start()
                if let item = response.mapItems.first {
                    await MainActor.run {
                        address = [
                            item.placemark.subThoroughfare,
                            item.placemark.thoroughfare,
                            item.placemark.locality,
                            item.placemark.administrativeArea,
                            item.placemark.postalCode
                        ]
                        .compactMap { $0 }
                        .joined(separator: " ")
                        
                        coordinate = item.placemark.coordinate
                        isShowingResults = false
                        isFocused = false
                    }
                }
            } catch {
                print("Address search error: \(error)")
            }
        }
    }
}

@MainActor
final class AddressSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    
    private let completer = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }
    
    func search(query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }
        completer.queryFragment = query
    }
    
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.results = completer.results
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.results = []
        }
    }
}

@MainActor
final class CreateProjectViewModel: ObservableObject {
    @Published var name = ""
    @Published var address = ""
    @Published var clientName = ""
    @Published var status: ProjectStatus = .walkthrough
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var error: String?
    
    private let apiClient = APIClient.shared
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func syncProject(_ project: Project) async {
        let request = CreateProjectRequest(
            name: project.name,
            address: project.address,
            latitude: project.latitude,
            longitude: project.longitude,
            clientName: project.clientName,
            status: project.status.rawValue
        )
        
        do {
            let response = try await apiClient.createProject(request)
            project.remoteId = response.id
            project.syncStatus = .synced
        } catch {
            project.syncStatus = .failed
            self.error = "Failed to sync project. It will be synced when connection is restored."
        }
    }
}

#Preview {
    CreateProjectView()
        .modelContainer(for: Project.self, inMemory: true)
}
