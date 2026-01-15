import Foundation
import UIKit

final class MediaStorage {
    static let shared = MediaStorage()
    
    private let fileManager = FileManager.default
    private let mediaDirectory: URL
    private let thumbnailDirectory: URL
    
    private init() {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        mediaDirectory = documents.appendingPathComponent(Constants.Storage.mediaDirectoryName)
        thumbnailDirectory = documents.appendingPathComponent(Constants.Storage.thumbnailDirectoryName)
        
        createDirectoriesIfNeeded()
    }
    
    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)
    }
    
    func saveImage(_ data: Data, fileName: String) -> String {
        let url = mediaDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)
        return url.path
    }
    
    func saveThumbnail(_ imageData: Data, fileName: String) -> String? {
        guard let image = UIImage(data: imageData),
              let thumbnailImage = image.preparingThumbnail(of: CGSize(
                width: Constants.Storage.maxThumbnailSize,
                height: Constants.Storage.maxThumbnailSize
              )),
              let thumbnailData = thumbnailImage.jpegData(compressionQuality: Constants.Storage.thumbnailCompressionQuality)
        else {
            return nil
        }
        
        let url = thumbnailDirectory.appendingPathComponent(fileName)
        try? thumbnailData.write(to: url)
        return url.path
    }
    
    func saveVideo(from sourceURL: URL, fileName: String) -> String {
        let destinationURL = mediaDirectory.appendingPathComponent(fileName)
        try? fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL.path
    }
    
    func saveVoiceNote(_ data: Data, fileName: String) -> String {
        let url = mediaDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)
        return url.path
    }
    
    func getMediaURL(for path: String) -> URL? {
        guard fileManager.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }
    
    func deleteMedia(at path: String) {
        try? fileManager.removeItem(atPath: path)
    }
    
    func clearAllMedia() {
        try? fileManager.removeItem(at: mediaDirectory)
        try? fileManager.removeItem(at: thumbnailDirectory)
        createDirectoriesIfNeeded()
    }
    
    var totalMediaSize: Int64 {
        let mediaSize = directorySize(at: mediaDirectory)
        let thumbnailSize = directorySize(at: thumbnailDirectory)
        return mediaSize + thumbnailSize
    }
    
    var formattedMediaSize: String {
        let bytes = totalMediaSize
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var size: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            size += Int64(fileSize)
        }
        return size
    }
}
