import SwiftUI
import MapKit

struct PhotoDetailView: View {
    let photo: Photo
    let project: Project
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingMetadata = true
    @State private var showingComments = false
    @State private var newComment = ""
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        photoView(geometry: geometry)
                        
                        if showingMetadata {
                            metadataPanel
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingMetadata.toggle()
                        } label: {
                            Label(showingMetadata ? "Hide Info" : "Show Info", systemImage: "info.circle")
                        }
                        
                        Button {
                            showingComments = true
                        } label: {
                            Label("Comments (\(photo.commentCount))", systemImage: "bubble.left")
                        }
                        
                        Divider()
                        
                        ShareLink(item: photo.localURL ?? URL(fileURLWithPath: "")) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingComments) {
                CommentsView(photo: photo)
            }
        }
    }
    
    private func photoView(geometry: GeometryProxy) -> some View {
        Group {
            if let url = photo.localURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = value
                                }
                                .onEnded { _ in
                                    withAnimation {
                                        scale = max(1.0, min(scale, 3.0))
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                scale = scale > 1.0 ? 1.0 : 2.0
                            }
                        }
                } placeholder: {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: showingMetadata ? geometry.size.height * 0.6 : .infinity)
    }
    
    private var metadataPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FVSpacing.md) {
                if let note = photo.displayNote {
                    VStack(alignment: .leading, spacing: FVSpacing.xs) {
                        Label("Note", systemImage: "text.bubble")
                            .font(FVTypography.caption)
                            .foregroundStyle(FVColors.secondaryLabel)
                        
                        Text(note)
                            .font(FVTypography.body)
                            .foregroundStyle(FVColors.label)
                    }
                }
                
                HStack(spacing: FVSpacing.lg) {
                    metadataItem(icon: "calendar", title: "Date", value: photo.capturedAt.formatted(date: .abbreviated, time: .omitted))
                    metadataItem(icon: "clock", title: "Time", value: photo.capturedAt.formatted(date: .omitted, time: .shortened))
                }
                
                if let uploaderName = photo.uploaderName {
                    metadataItem(icon: "person", title: "Captured by", value: uploaderName)
                }
                
                metadataItem(icon: "location", title: "Location", value: String(format: "%.6f, %.6f", photo.latitude, photo.longitude))
                
                if photo.latitude != 0 && photo.longitude != 0 {
                    Map(position: .constant(.region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: photo.latitude, longitude: photo.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    )))) {
                        Marker("", coordinate: CLLocationCoordinate2D(latitude: photo.latitude, longitude: photo.longitude))
                    }
                    .frame(height: 120)
                    .cornerRadius(FVRadius.sm)
                    .disabled(true)
                }
                
                if let folder = photo.folder {
                    metadataItem(icon: "folder", title: "Folder", value: folder.name)
                }
            }
            .padding()
        }
        .background(FVColors.background)
        .cornerRadius(FVRadius.lg, corners: [.topLeft, .topRight])
    }
    
    private func metadataItem(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: FVSpacing.xxxs) {
            Label(title, systemImage: icon)
                .font(FVTypography.caption)
                .foregroundStyle(FVColors.secondaryLabel)
            
            Text(value)
                .font(FVTypography.subheadline)
                .foregroundStyle(FVColors.label)
        }
    }
}

struct CommentsView: View {
    let photo: Photo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var newComment = ""
    @FocusState private var isCommentFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if photo.comments.isEmpty {
                    emptyState
                } else {
                    commentsList
                }
                
                commentInput
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: FVSpacing.md) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(FVColors.tertiaryLabel)
            
            Text("No comments yet")
                .font(FVTypography.headline)
                .foregroundStyle(FVColors.label)
            
            Text("Be the first to add a comment")
                .font(FVTypography.subheadline)
                .foregroundStyle(FVColors.secondaryLabel)
            
            Spacer()
        }
    }
    
    private var commentsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: FVSpacing.md) {
                ForEach(photo.comments.sorted { $0.createdAt < $1.createdAt }) { comment in
                    CommentRow(comment: comment)
                }
            }
            .padding()
        }
    }
    
    private var commentInput: some View {
        HStack(spacing: FVSpacing.sm) {
            TextField("Add a comment...", text: $newComment)
                .textFieldStyle(.plain)
                .focused($isCommentFieldFocused)
            
            Button {
                addComment()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(newComment.isEmpty ? FVColors.tertiaryLabel : FVColors.Fallback.primary)
            }
            .disabled(newComment.isEmpty)
        }
        .padding()
        .background(FVColors.secondaryBackground)
    }
    
    private func addComment() {
        guard !newComment.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let comment = Comment(
            userId: KeychainService.shared.getUserId() ?? UUID(),
            userName: "You",
            text: newComment,
            photo: photo
        )
        
        modelContext.insert(comment)
        newComment = ""
        isCommentFieldFocused = false
    }
}

struct CommentRow: View {
    let comment: Comment
    
    var body: some View {
        HStack(alignment: .top, spacing: FVSpacing.sm) {
            Circle()
                .fill(FVColors.Fallback.primary.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(comment.userInitials)
                        .font(FVTypography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(FVColors.Fallback.primary)
                }
            
            VStack(alignment: .leading, spacing: FVSpacing.xxxs) {
                HStack {
                    Text(comment.userName)
                        .font(FVTypography.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(FVColors.label)
                    
                    Text(comment.formattedDate)
                        .font(FVTypography.caption)
                        .foregroundStyle(FVColors.tertiaryLabel)
                }
                
                Text(comment.text)
                    .font(FVTypography.body)
                    .foregroundStyle(FVColors.label)
            }
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    PhotoDetailView(
        photo: Photo(uploaderId: UUID(), capturedAt: Date(), latitude: 37.7749, longitude: -122.4194, localPath: ""),
        project: Project(name: "Test", address: "123 Main St")
    )
}
