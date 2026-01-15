import SwiftUI
import SwiftData

struct TimelineView: View {
    @Bindable var project: Project

    @State private var selectedPhoto: Photo?
    @State private var filterDateRange: ClosedRange<Date>?
    @State private var filterFolder: Folder?

    private var groupedPhotos: [(Date, [Photo])] {
        let calendar = Calendar.current
        let sorted = project.photos.sorted { $0.capturedAt > $1.capturedAt }

        var groups: [Date: [Photo]] = [:]
        for photo in sorted {
            let dayStart = calendar.startOfDay(for: photo.capturedAt)
            groups[dayStart, default: []].append(photo)
        }

        return groups.sorted { $0.key > $1.key }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedPhotos, id: \.0) { date, photos in
                    Section {
                        photoGrid(photos: photos)
                    } header: {
                        dateHeader(date: date, count: photos.count)
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo, project: project)
        }
    }

    private func dateHeader(date: Date, count: Int) -> some View {
        HStack {
            Text(formatDate(date))
                .font(FVTypography.headline)
                .foregroundStyle(FVColors.label)

            Spacer()

            Text("\(count) photos")
                .font(FVTypography.caption)
                .foregroundStyle(FVColors.secondaryLabel)
        }
        .padding(.horizontal)
        .padding(.vertical, FVSpacing.sm)
        .background(FVColors.background.opacity(0.95))
    }

    private func photoGrid(photos: [Photo]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: Constants.UI.gridSpacing),
            GridItem(.flexible(), spacing: Constants.UI.gridSpacing),
            GridItem(.flexible(), spacing: Constants.UI.gridSpacing)
        ], spacing: Constants.UI.gridSpacing) {
            ForEach(photos) { photo in
                PhotoThumbnail(photo: photo)
                    .onTapGesture {
                        selectedPhoto = photo
                    }
            }
        }
        .padding(.horizontal, Constants.UI.gridSpacing)
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.month().day().year())
        }
    }
}

struct PhotoThumbnail: View {
    let photo: Photo

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                if let url = photo.thumbnailURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(FVColors.tertiaryBackground)
                            .overlay {
                                ProgressView()
                            }
                    }
                } else {
                    Rectangle()
                        .fill(FVColors.tertiaryBackground)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(FVColors.tertiaryLabel)
                        }
                }

                if photo.mediaType == .video {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(.black.opacity(0.6))
                        .cornerRadius(4)
                        .padding(4)
                }

                if photo.hasNote {
                    Image(systemName: "text.bubble.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(.black.opacity(0.6))
                        .cornerRadius(4)
                        .padding(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    TimelineView(project: Project(name: "Test", address: "123 Main St"))
}
