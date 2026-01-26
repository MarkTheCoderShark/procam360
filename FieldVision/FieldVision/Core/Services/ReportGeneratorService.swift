import Foundation
import UIKit
import PDFKit

struct ReportConfiguration {
    var includeNotes: Bool = true
    var includeTranscriptions: Bool = true
    var includeTimestamps: Bool = true
    var includeLocation: Bool = true
    var selectedFolderIds: Set<UUID>?
    var dateRange: ClosedRange<Date>?
    var photosPerPage: PhotosPerPage = .two
    var includeTableOfContents: Bool = true
    var includeCoverPage: Bool = true
    var includeProjectSummary: Bool = true
    var companyName: String?
    var companyLogo: UIImage?

    enum PhotosPerPage: Int, CaseIterable {
        case one = 1
        case two = 2
        case four = 4

        var displayName: String {
            switch self {
            case .one: return "1 per page (Large)"
            case .two: return "2 per page (Medium)"
            case .four: return "4 per page (Small)"
            }
        }
    }
}

final class ReportGeneratorService {
    static let shared = ReportGeneratorService()

    private let pageWidth: CGFloat = 612
    private let pageHeight: CGFloat = 792
    private let margin: CGFloat = 50

    private var contentWidth: CGFloat { pageWidth - (margin * 2) }
    private var contentHeight: CGFloat { pageHeight - (margin * 2) }

    private init() {}

    func generateReport(
        for project: Project,
        configuration: ReportConfiguration,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let photos = filteredPhotos(from: project, configuration: configuration)
        let folders = filteredFolders(from: project, configuration: configuration)

        let pdfMetaData = [
            kCGPDFContextCreator: "ProCam360",
            kCGPDFContextAuthor: configuration.companyName ?? "ProCam360 User",
            kCGPDFContextTitle: "\(project.name) Report",
            kCGPDFContextSubject: "Photo Documentation Report"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let totalItems = photos.count + (configuration.includeCoverPage ? 1 : 0) + (configuration.includeTableOfContents ? 1 : 0)
        var processedItems = 0

        let data = renderer.pdfData { context in
            if configuration.includeCoverPage {
                drawCoverPage(context: context, project: project, configuration: configuration)
                processedItems += 1
                progress(Double(processedItems) / Double(totalItems))
            }

            if configuration.includeTableOfContents {
                drawTableOfContents(context: context, project: project, folders: folders, photos: photos)
                processedItems += 1
                progress(Double(processedItems) / Double(totalItems))
            }

            if configuration.includeProjectSummary {
                drawProjectSummary(context: context, project: project, photos: photos, folders: folders)
            }

            drawPhotos(
                context: context,
                project: project,
                photos: photos,
                folders: folders,
                configuration: configuration,
                progressUpdate: { itemsProcessed in
                    progress(Double(processedItems + itemsProcessed) / Double(totalItems))
                }
            )
        }

        let fileName = "\(project.name.replacingOccurrences(of: " ", with: "_"))_Report_\(Date().formatted(.iso8601.year().month().day())).pdf"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let reportsDirectory = documentsPath.appendingPathComponent("Reports")

        try? FileManager.default.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)

        let fileURL = reportsDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL)

        return fileURL
    }

    private func filteredPhotos(from project: Project, configuration: ReportConfiguration) -> [Photo] {
        var photos = project.photos

        if let folderIds = configuration.selectedFolderIds {
            photos = photos.filter { photo in
                guard let folderId = photo.folder?.id else { return false }
                return folderIds.contains(folderId)
            }
        }

        if let dateRange = configuration.dateRange {
            photos = photos.filter { dateRange.contains($0.capturedAt) }
        }

        return photos.sorted { $0.capturedAt < $1.capturedAt }
    }

    private func filteredFolders(from project: Project, configuration: ReportConfiguration) -> [Folder] {
        var folders = project.folders

        if let folderIds = configuration.selectedFolderIds {
            folders = folders.filter { folderIds.contains($0.id) }
        }

        return folders.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func drawCoverPage(context: UIGraphicsPDFRendererContext, project: Project, configuration: ReportConfiguration) {
        context.beginPage()

        let titleFont = UIFont.systemFont(ofSize: 32, weight: .bold)
        let subtitleFont = UIFont.systemFont(ofSize: 18, weight: .medium)
        let bodyFont = UIFont.systemFont(ofSize: 14, weight: .regular)

        var yPosition: CGFloat = pageHeight * 0.3

        if let logo = configuration.companyLogo {
            let logoMaxWidth: CGFloat = 200
            let logoMaxHeight: CGFloat = 100
            let aspectRatio = logo.size.width / logo.size.height
            var logoWidth = logoMaxWidth
            var logoHeight = logoWidth / aspectRatio

            if logoHeight > logoMaxHeight {
                logoHeight = logoMaxHeight
                logoWidth = logoHeight * aspectRatio
            }

            let logoRect = CGRect(
                x: (pageWidth - logoWidth) / 2,
                y: margin + 40,
                width: logoWidth,
                height: logoHeight
            )
            logo.draw(in: logoRect)
            yPosition = logoRect.maxY + 60
        }

        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .center

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black,
            .paragraphStyle: titleParagraph
        ]

        let titleRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 50)
        (project.name as NSString).draw(in: titleRect, withAttributes: titleAttributes)
        yPosition += 60

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: titleParagraph
        ]

        ("Photo Documentation Report" as NSString).draw(
            in: CGRect(x: margin, y: yPosition, width: contentWidth, height: 30),
            withAttributes: subtitleAttributes
        )
        yPosition += 80

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: titleParagraph
        ]

        let details = [
            "Address: \(project.address)",
            project.clientName.map { "Client: \($0)" },
            "Status: \(project.status.displayName)",
            "Generated: \(Date().formatted(date: .long, time: .shortened))"
        ].compactMap { $0 }

        for detail in details {
            (detail as NSString).draw(
                in: CGRect(x: margin, y: yPosition, width: contentWidth, height: 24),
                withAttributes: bodyAttributes
            )
            yPosition += 28
        }

        if let companyName = configuration.companyName {
            yPosition = pageHeight - margin - 60

            let companyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.gray,
                .paragraphStyle: titleParagraph
            ]

            ("Prepared by \(companyName)" as NSString).draw(
                in: CGRect(x: margin, y: yPosition, width: contentWidth, height: 20),
                withAttributes: companyAttributes
            )
        }
    }

    private func drawTableOfContents(
        context: UIGraphicsPDFRendererContext,
        project: Project,
        folders: [Folder],
        photos: [Photo]
    ) {
        context.beginPage()

        let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
        let sectionFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let itemFont = UIFont.systemFont(ofSize: 12, weight: .regular)

        var yPosition: CGFloat = margin

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]

        ("Table of Contents" as NSString).draw(
            at: CGPoint(x: margin, y: yPosition),
            withAttributes: titleAttributes
        )
        yPosition += 50

        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: sectionFont,
            .foregroundColor: UIColor.black
        ]

        let itemAttributes: [NSAttributedString.Key: Any] = [
            .font: itemFont,
            .foregroundColor: UIColor.darkGray
        ]

        ("Project Summary" as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
        yPosition += 30

        ("Folders (\(folders.count))" as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
        yPosition += 24

        for folder in folders {
            let folderText = "  \(folder.name) - \(folder.photoCount) photos"
            (folderText as NSString).draw(at: CGPoint(x: margin + 20, y: yPosition), withAttributes: itemAttributes)
            yPosition += 20

            if yPosition > contentHeight - 50 {
                context.beginPage()
                yPosition = margin
            }
        }

        yPosition += 10
        ("Total Photos: \(photos.count)" as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
    }

    private func drawProjectSummary(
        context: UIGraphicsPDFRendererContext,
        project: Project,
        photos: [Photo],
        folders: [Folder]
    ) {
        context.beginPage()

        let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
        let labelFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let valueFont = UIFont.systemFont(ofSize: 12, weight: .regular)

        var yPosition: CGFloat = margin

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]

        ("Project Summary" as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
        yPosition += 50

        let summaryData: [(String, String)] = [
            ("Project Name:", project.name),
            ("Address:", project.address),
            ("Client:", project.clientName ?? "N/A"),
            ("Status:", project.status.displayName),
            ("Created:", project.createdAt.formatted(date: .long, time: .omitted)),
            ("Last Updated:", project.updatedAt.formatted(date: .long, time: .shortened)),
            ("Total Folders:", "\(folders.count)"),
            ("Total Photos:", "\(photos.count)")
        ]

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.darkGray
        ]

        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: UIColor.black
        ]

        for (label, value) in summaryData {
            (label as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: labelAttributes)
            (value as NSString).draw(at: CGPoint(x: margin + 120, y: yPosition), withAttributes: valueAttributes)
            yPosition += 24
        }

        if !photos.isEmpty {
            yPosition += 20

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium

            if let firstPhoto = photos.min(by: { $0.capturedAt < $1.capturedAt }),
               let lastPhoto = photos.max(by: { $0.capturedAt < $1.capturedAt }) {
                ("Date Range:" as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: labelAttributes)

                let dateRangeText = "\(dateFormatter.string(from: firstPhoto.capturedAt)) - \(dateFormatter.string(from: lastPhoto.capturedAt))"
                (dateRangeText as NSString).draw(at: CGPoint(x: margin + 120, y: yPosition), withAttributes: valueAttributes)
                yPosition += 24
            }

            let photosWithNotes = photos.filter { $0.hasNote }.count
            ("Photos with Notes:" as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: labelAttributes)
            ("\(photosWithNotes)" as NSString).draw(at: CGPoint(x: margin + 120, y: yPosition), withAttributes: valueAttributes)
        }
    }

    private func drawPhotos(
        context: UIGraphicsPDFRendererContext,
        project: Project,
        photos: [Photo],
        folders: [Folder],
        configuration: ReportConfiguration,
        progressUpdate: @escaping (Int) -> Void
    ) {
        let photosPerPage = configuration.photosPerPage.rawValue
        let groupedPhotos = Dictionary(grouping: photos) { $0.folder?.id }

        var processedCount = 0

        for folder in folders {
            guard let folderPhotos = groupedPhotos[folder.id], !folderPhotos.isEmpty else { continue }

            context.beginPage()
            drawFolderHeader(folder: folder, at: margin)

            var yPosition: CGFloat = margin + 60
            var photosOnCurrentPage = 0

            for photo in folderPhotos.sorted(by: { $0.capturedAt < $1.capturedAt }) {
                if photosOnCurrentPage >= photosPerPage {
                    context.beginPage()
                    drawFolderHeader(folder: folder, at: margin, isContinuation: true)
                    yPosition = margin + 60
                    photosOnCurrentPage = 0
                }

                yPosition = drawPhoto(
                    photo: photo,
                    at: yPosition,
                    configuration: configuration,
                    photosPerPage: photosPerPage
                )

                photosOnCurrentPage += 1
                processedCount += 1
                progressUpdate(processedCount)
            }
        }

        let unfolderedPhotos = photos.filter { $0.folder == nil }
        if !unfolderedPhotos.isEmpty {
            context.beginPage()

            let titleFont = UIFont.systemFont(ofSize: 18, weight: .bold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            ("Uncategorized Photos" as NSString).draw(at: CGPoint(x: margin, y: margin), withAttributes: titleAttributes)

            var yPosition: CGFloat = margin + 50
            var photosOnCurrentPage = 0

            for photo in unfolderedPhotos.sorted(by: { $0.capturedAt < $1.capturedAt }) {
                if photosOnCurrentPage >= photosPerPage {
                    context.beginPage()
                    yPosition = margin
                    photosOnCurrentPage = 0
                }

                yPosition = drawPhoto(
                    photo: photo,
                    at: yPosition,
                    configuration: configuration,
                    photosPerPage: photosPerPage
                )

                photosOnCurrentPage += 1
                processedCount += 1
                progressUpdate(processedCount)
            }
        }
    }

    private func drawFolderHeader(folder: Folder, at yPosition: CGFloat, isContinuation: Bool = false) {
        let titleFont = UIFont.systemFont(ofSize: 18, weight: .bold)
        let subtitleFont = UIFont.systemFont(ofSize: 12, weight: .regular)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: UIColor.gray
        ]

        let title = isContinuation ? "\(folder.name) (continued)" : folder.name
        (title as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)

        let subtitle = "\(folder.folderType.displayName) • \(folder.photoCount) photos"
        (subtitle as NSString).draw(at: CGPoint(x: margin, y: yPosition + 24), withAttributes: subtitleAttributes)

        let lineY = yPosition + 48
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: lineY))
        path.addLine(to: CGPoint(x: pageWidth - margin, y: lineY))
        UIColor.lightGray.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    private func drawPhoto(
        photo: Photo,
        at startY: CGFloat,
        configuration: ReportConfiguration,
        photosPerPage: Int
    ) -> CGFloat {
        var yPosition = startY

        let imageHeight: CGFloat
        switch photosPerPage {
        case 1: imageHeight = 400
        case 2: imageHeight = 250
        case 4: imageHeight = 140
        default: imageHeight = 250
        }

        if let localURL = photo.localURL,
           let imageData = try? Data(contentsOf: localURL),
           let image = UIImage(data: imageData) {

            let imageWidth = contentWidth
            let aspectRatio = image.size.width / image.size.height
            var displayWidth = imageWidth
            var displayHeight = displayWidth / aspectRatio

            if displayHeight > imageHeight {
                displayHeight = imageHeight
                displayWidth = displayHeight * aspectRatio
            }

            let imageRect = CGRect(
                x: margin + (contentWidth - displayWidth) / 2,
                y: yPosition,
                width: displayWidth,
                height: displayHeight
            )

            UIColor.lightGray.setStroke()
            let borderPath = UIBezierPath(rect: imageRect.insetBy(dx: -1, dy: -1))
            borderPath.lineWidth = 0.5
            borderPath.stroke()

            image.draw(in: imageRect)
            yPosition = imageRect.maxY + 8
        }

        let captionFont = UIFont.systemFont(ofSize: 10, weight: .regular)
        let noteFont = UIFont.systemFont(ofSize: 11, weight: .regular)

        let captionAttributes: [NSAttributedString.Key: Any] = [
            .font: captionFont,
            .foregroundColor: UIColor.gray
        ]

        let noteAttributes: [NSAttributedString.Key: Any] = [
            .font: noteFont,
            .foregroundColor: UIColor.darkGray
        ]

        var captionParts: [String] = []

        if configuration.includeTimestamps {
            captionParts.append(photo.capturedAt.formatted(date: .abbreviated, time: .shortened))
        }

        if configuration.includeLocation {
            let lat = String(format: "%.4f", photo.latitude)
            let lon = String(format: "%.4f", photo.longitude)
            captionParts.append("📍 \(lat), \(lon)")
        }

        if photo.uploaderName != nil {
            captionParts.append("By: \(photo.uploaderName!)")
        }

        if !captionParts.isEmpty {
            let caption = captionParts.joined(separator: " • ")
            (caption as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: captionAttributes)
            yPosition += 16
        }

        if configuration.includeNotes, let note = photo.note, !note.isEmpty {
            let noteRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 60)
            (note as NSString).draw(in: noteRect, withAttributes: noteAttributes)
            yPosition += min(60, note.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: noteAttributes, context: nil).height) + 8
        }

        if configuration.includeTranscriptions, let transcription = photo.voiceNoteTranscription, !transcription.isEmpty {
            let transcriptionLabel = "🎤 Voice Note: "
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: UIColor.gray
            ]
            (transcriptionLabel as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: labelAttributes)
            yPosition += 14

            let transcriptionRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 50)
            (transcription as NSString).draw(in: transcriptionRect, withAttributes: noteAttributes)
            yPosition += min(50, transcription.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: noteAttributes, context: nil).height) + 8
        }

        yPosition += 20
        return yPosition
    }

    func getSavedReports() -> [URL] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let reportsDirectory = documentsPath.appendingPathComponent("Reports")

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: reportsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return contents
            .filter { $0.pathExtension == "pdf" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                return date1 > date2
            }
    }

    func deleteReport(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
