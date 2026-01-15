import SwiftUI
import SwiftData
import Charts

struct ActivityDashboardView: View {
    @Query private var projects: [Project]
    @Query private var photos: [Photo]
    
    @State private var selectedTimeRange: TimeRange = .week
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FVSpacing.lg) {
                    timeRangePicker
                    
                    statsCardsSection
                    
                    photosChartSection
                    
                    recentActivitySection
                    
                    projectStatusSection
                }
                .padding()
            }
            .navigationTitle("Activity")
            .background(FVColors.groupedBackground)
        }
    }
    
    private var timeRangePicker: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var statsCardsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: FVSpacing.md) {
            StatCard(
                title: "Total Photos",
                value: "\(photos.count)",
                icon: "photo.stack.fill",
                color: .blue
            )
            
            StatCard(
                title: "Active Projects",
                value: "\(activeProjectsCount)",
                icon: "folder.fill",
                color: .orange
            )
            
            StatCard(
                title: "This \(selectedTimeRange.periodName)",
                value: "\(photosInTimeRange)",
                icon: "camera.fill",
                color: .green
            )
            
            StatCard(
                title: "Storage Used",
                value: MediaStorage.shared.formattedMediaSize,
                icon: "internaldrive.fill",
                color: .purple
            )
        }
    }
    
    private var photosChartSection: some View {
        VStack(alignment: .leading, spacing: FVSpacing.sm) {
            Text("Photo Activity")
                .font(FVTypography.headline)
                .foregroundStyle(FVColors.label)
            
            Chart {
                ForEach(photoActivityData, id: \.date) { dataPoint in
                    BarMark(
                        x: .value("Date", dataPoint.date, unit: chartUnit),
                        y: .value("Photos", dataPoint.count)
                    )
                    .foregroundStyle(FVColors.Fallback.primary.gradient)
                    .cornerRadius(4)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: chartDateFormat)
                }
            }
        }
        .padding()
        .background(FVColors.background)
        .cornerRadius(FVRadius.md)
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: FVSpacing.sm) {
            Text("Recent Activity")
                .font(FVTypography.headline)
                .foregroundStyle(FVColors.label)
            
            if recentPhotos.isEmpty {
                Text("No recent photos")
                    .font(FVTypography.subheadline)
                    .foregroundStyle(FVColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, FVSpacing.lg)
            } else {
                ForEach(recentPhotos.prefix(5)) { photo in
                    ActivityRow(photo: photo)
                }
            }
        }
        .padding()
        .background(FVColors.background)
        .cornerRadius(FVRadius.md)
    }
    
    private var projectStatusSection: some View {
        VStack(alignment: .leading, spacing: FVSpacing.sm) {
            Text("Projects by Status")
                .font(FVTypography.headline)
                .foregroundStyle(FVColors.label)
            
            HStack(spacing: FVSpacing.md) {
                ProjectStatusPill(
                    status: .walkthrough,
                    count: projectsWithStatus(.walkthrough)
                )
                
                ProjectStatusPill(
                    status: .inProgress,
                    count: projectsWithStatus(.inProgress)
                )
                
                ProjectStatusPill(
                    status: .completed,
                    count: projectsWithStatus(.completed)
                )
            }
        }
        .padding()
        .background(FVColors.background)
        .cornerRadius(FVRadius.md)
    }
    
    private var activeProjectsCount: Int {
        projects.filter { $0.status != .completed }.count
    }
    
    private var photosInTimeRange: Int {
        let startDate = selectedTimeRange.startDate
        return photos.filter { $0.capturedAt >= startDate }.count
    }
    
    private var recentPhotos: [Photo] {
        photos.sorted { $0.capturedAt > $1.capturedAt }
    }
    
    private var photoActivityData: [PhotoActivityDataPoint] {
        let startDate = selectedTimeRange.startDate
        let calendar = Calendar.current
        
        let filteredPhotos = photos.filter { $0.capturedAt >= startDate }
        
        var dataPoints: [Date: Int] = [:]
        
        for photo in filteredPhotos {
            let components: Set<Calendar.Component> = selectedTimeRange == .year ? [.year, .month] : [.year, .month, .day]
            let dateComponents = calendar.dateComponents(components, from: photo.capturedAt)
            if let date = calendar.date(from: dateComponents) {
                dataPoints[date, default: 0] += 1
            }
        }
        
        return dataPoints.map { PhotoActivityDataPoint(date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    private var chartUnit: Calendar.Component {
        selectedTimeRange == .year ? .month : .day
    }
    
    private var chartDateFormat: Date.FormatStyle {
        selectedTimeRange == .year ? .dateTime.month(.abbreviated) : .dateTime.day()
    }
    
    private func projectsWithStatus(_ status: ProjectStatus) -> Int {
        projects.filter { $0.status == status }.count
    }
}

struct PhotoActivityDataPoint {
    let date: Date
    let count: Int
}

enum TimeRange: String, CaseIterable {
    case week
    case month
    case year
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
    
    var periodName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
    
    var startDate: Date {
        let calendar = Calendar.current
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: FVSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(FVColors.label)
            
            Text(title)
                .font(FVTypography.caption)
                .foregroundStyle(FVColors.secondaryLabel)
        }
        .padding()
        .background(FVColors.background)
        .cornerRadius(FVRadius.md)
    }
}

struct ActivityRow: View {
    let photo: Photo
    
    var body: some View {
        HStack(spacing: FVSpacing.md) {
            if let url = photo.thumbnailURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(FVColors.tertiaryBackground)
                }
                .frame(width: 50, height: 50)
                .cornerRadius(FVRadius.sm)
            }
            
            VStack(alignment: .leading, spacing: FVSpacing.xxxs) {
                Text(photo.folder?.name ?? "Uncategorized")
                    .font(FVTypography.subheadline)
                    .foregroundStyle(FVColors.label)
                
                Text(photo.project?.name ?? "Unknown Project")
                    .font(FVTypography.caption)
                    .foregroundStyle(FVColors.secondaryLabel)
            }
            
            Spacer()
            
            Text(photo.capturedAt.formatted(.relative(presentation: .named)))
                .font(FVTypography.caption2)
                .foregroundStyle(FVColors.tertiaryLabel)
        }
        .padding(.vertical, FVSpacing.xs)
    }
}

struct ProjectStatusPill: View {
    let status: ProjectStatus
    let count: Int
    
    var body: some View {
        VStack(spacing: FVSpacing.xs) {
            Text("\(count)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(statusColor)
            
            Text(status.displayName)
                .font(FVTypography.caption2)
                .foregroundStyle(FVColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FVSpacing.sm)
        .background(statusColor.opacity(0.1))
        .cornerRadius(FVRadius.sm)
    }
    
    private var statusColor: Color {
        switch status {
        case .walkthrough: return FVColors.statusWalkthrough
        case .inProgress: return FVColors.statusInProgress
        case .completed: return FVColors.statusCompleted
        }
    }
}

#Preview {
    ActivityDashboardView()
        .modelContainer(for: [Project.self, Photo.self], inMemory: true)
}
