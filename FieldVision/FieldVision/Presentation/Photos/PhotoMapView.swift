import SwiftUI
import MapKit

struct PhotoMapView: View {
    @Bindable var project: Project

    @State private var selectedPhotos: [Photo] = []
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedPhoto: Photo?

    private var photosWithLocation: [Photo] {
        project.photos.filter { $0.latitude != 0 && $0.longitude != 0 }
    }

    var body: some View {
        Map(position: $position) {
            ForEach(photosWithLocation) { photo in
                Annotation("", coordinate: CLLocationCoordinate2D(
                    latitude: photo.latitude,
                    longitude: photo.longitude
                )) {
                    PhotoMapPin(photo: photo, isSelected: selectedPhotos.contains(where: { $0.id == photo.id }))
                        .onTapGesture {
                            withAnimation {
                                selectedPhotos = [photo]
                            }
                        }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapUserLocationButton()
        }
        .safeAreaInset(edge: .bottom) {
            if !selectedPhotos.isEmpty {
                selectedPhotoCarousel
            }
        }
        .onAppear {
            if let projectLat = project.latitude,
               let projectLon = project.longitude {
                position = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: projectLat, longitude: projectLon),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo, project: project)
        }
    }

    private var selectedPhotoCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FVSpacing.sm) {
                ForEach(selectedPhotos) { photo in
                    VStack(alignment: .leading, spacing: FVSpacing.xs) {
                        if let url = photo.thumbnailURL {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(FVColors.tertiaryBackground)
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: FVRadius.sm))
                        }

                        Text(photo.formattedDate)
                            .font(FVTypography.caption)
                            .foregroundStyle(FVColors.secondaryLabel)
                    }
                    .onTapGesture {
                        selectedPhoto = photo
                    }
                }
            }
            .padding()
        }
        .background(.ultraThinMaterial)
        .cornerRadius(FVRadius.lg)
        .padding()
    }
}

struct PhotoMapPin: View {
    let photo: Photo
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(FVColors.Fallback.primary)
                .frame(width: isSelected ? 44 : 32, height: isSelected ? 44 : 32)
                .shadow(radius: 2)

            if let url = photo.thumbnailURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "photo")
                        .foregroundStyle(.white)
                }
                .frame(width: isSelected ? 36 : 24, height: isSelected ? 36 : 24)
                .clipShape(Circle())
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.white)
            }
        }
        .animation(.spring(duration: 0.3), value: isSelected)
    }
}

#Preview {
    PhotoMapView(project: Project(name: "Test", address: "123 Main St"))
}
