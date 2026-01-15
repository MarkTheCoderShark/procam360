import SwiftUI

struct ShareConfigView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var scope: ShareScope = .entireProject
    @State private var selectedFolders: Set<UUID> = []
    @State private var dateRangeEnabled = false
    @State private var dateRangeStart = Date()
    @State private var dateRangeEnd = Date()
    @State private var expirationOption: ExpirationOption = .never
    @State private var customExpirationDate = Date().addingTimeInterval(7 * 24 * 60 * 60)
    @State private var passwordEnabled = false
    @State private var password = ""
    @State private var allowDownload = false
    @State private var allowComments = false
    
    @State private var generatedLink: String?
    @State private var isGenerating = false
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            if let link = generatedLink {
                linkGeneratedView(link: link)
            } else {
                configurationForm
            }
        }
    }
    
    private var configurationForm: some View {
        Form {
            Section("Scope") {
                Picker("Share", selection: $scope) {
                    Text("Entire Project").tag(ShareScope.entireProject)
                    Text("Selected Folders").tag(ShareScope.selectedFolders)
                }
                .pickerStyle(.segmented)
                
                if scope == .selectedFolders {
                    ForEach(project.folders) { folder in
                        Button {
                            if selectedFolders.contains(folder.id) {
                                selectedFolders.remove(folder.id)
                            } else {
                                selectedFolders.insert(folder.id)
                            }
                        } label: {
                            HStack {
                                Label(folder.name, systemImage: folder.folderType.iconName)
                                    .foregroundStyle(FVColors.label)
                                
                                Spacer()
                                
                                if selectedFolders.contains(folder.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(FVColors.Fallback.primary)
                                }
                            }
                        }
                    }
                }
            }
            
            Section("Date Range (Optional)") {
                Toggle("Filter by date range", isOn: $dateRangeEnabled)
                
                if dateRangeEnabled {
                    DatePicker("From", selection: $dateRangeStart, displayedComponents: .date)
                    DatePicker("To", selection: $dateRangeEnd, displayedComponents: .date)
                }
            }
            
            Section("Link Expiration") {
                Picker("Expires", selection: $expirationOption) {
                    ForEach(ExpirationOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                
                if expirationOption == .custom {
                    DatePicker("Expiration Date", selection: $customExpirationDate, displayedComponents: .date)
                }
            }
            
            Section("Security") {
                Toggle("Password protected", isOn: $passwordEnabled)
                
                if passwordEnabled {
                    SecureField("Password", text: $password)
                }
            }
            
            Section("Permissions") {
                Toggle("Allow downloads", isOn: $allowDownload)
                Toggle("Allow comments", isOn: $allowComments)
            }
            
            if let error = error {
                Section {
                    Text(error)
                        .foregroundStyle(FVColors.error)
                }
            }
        }
        .navigationTitle("Share Project")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Generate Link") {
                    generateLink()
                }
                .disabled(isGenerating || (scope == .selectedFolders && selectedFolders.isEmpty))
                .fontWeight(.semibold)
            }
        }
    }
    
    private func linkGeneratedView(link: String) -> some View {
        VStack(spacing: FVSpacing.xl) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(FVColors.success)
            
            Text("Link Created!")
                .font(FVTypography.title)
                .foregroundStyle(FVColors.label)
            
            Text(link)
                .font(FVTypography.caption)
                .foregroundStyle(FVColors.secondaryLabel)
                .padding()
                .background(FVColors.secondaryBackground)
                .cornerRadius(FVRadius.sm)
            
            Spacer()
            
            VStack(spacing: FVSpacing.sm) {
                Button {
                    UIPasteboard.general.string = link
                } label: {
                    Label("Copy Link", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                ShareLink(item: URL(string: link)!) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button("Done") {
                    dismiss()
                }
                .padding(.top)
            }
            .padding(.horizontal)
            .padding(.bottom, FVSpacing.xl)
        }
        .navigationTitle("Share Link")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
    
    private func generateLink() {
        isGenerating = true
        error = nil
        
        let shareLink = ProjectShareLink(
            folderIds: scope == .selectedFolders ? Array(selectedFolders) : [],
            dateRangeStart: dateRangeEnabled ? dateRangeStart : nil,
            dateRangeEnd: dateRangeEnabled ? dateRangeEnd : nil,
            expiresAt: expirationOption.date(from: customExpirationDate),
            passwordProtected: passwordEnabled,
            allowDownload: allowDownload,
            allowComments: allowComments,
            createdById: KeychainService.shared.getUserId() ?? UUID(),
            project: project
        )
        
        modelContext.insert(shareLink)
        
        generatedLink = shareLink.shareURL?.absoluteString ?? "https://fieldvision.app/share/\(shareLink.token)"
        isGenerating = false
    }
}

enum ShareScope {
    case entireProject
    case selectedFolders
}

enum ExpirationOption: CaseIterable {
    case never
    case sevenDays
    case thirtyDays
    case custom
    
    var displayName: String {
        switch self {
        case .never: return "Never"
        case .sevenDays: return "7 days"
        case .thirtyDays: return "30 days"
        case .custom: return "Custom date"
        }
    }
    
    func date(from customDate: Date) -> Date? {
        switch self {
        case .never:
            return nil
        case .sevenDays:
            return Date().addingTimeInterval(7 * 24 * 60 * 60)
        case .thirtyDays:
            return Date().addingTimeInterval(30 * 24 * 60 * 60)
        case .custom:
            return customDate
        }
    }
}

#Preview {
    ShareConfigView(project: Project(name: "Test", address: "123 Main St"))
}
