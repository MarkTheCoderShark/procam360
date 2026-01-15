import Foundation
import SwiftUI
import UIKit

final class ImageCache {
    static let shared = ImageCache()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024
        
        let cachePath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachePath.appendingPathComponent("ImageCache", isDirectory: true)
        
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func image(for key: String) -> UIImage? {
        let nsKey = key as NSString
        
        if let cached = memoryCache.object(forKey: nsKey) {
            return cached
        }
        
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256Hash)
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: nsKey, cost: data.count)
            return image
        }
        
        return nil
    }
    
    func setImage(_ image: UIImage, for key: String) {
        let nsKey = key as NSString
        
        if let data = image.jpegData(compressionQuality: 0.8) {
            memoryCache.setObject(image, forKey: nsKey, cost: data.count)
            
            let fileURL = cacheDirectory.appendingPathComponent(key.sha256Hash)
            try? data.write(to: fileURL)
        }
    }
    
    func removeImage(for key: String) {
        let nsKey = key as NSString
        memoryCache.removeObject(forKey: nsKey)
        
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256Hash)
        try? fileManager.removeItem(at: fileURL)
    }
    
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    func clearDiskCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func diskCacheSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = resourceValues.fileSize {
                totalSize += Int64(size)
            }
        }
        
        return totalSize
    }
}

extension String {
    var sha256Hash: String {
        let data = Data(self.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

import CommonCrypto

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let scale: CGFloat
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    init(
        url: URL?,
        scale: CGFloat = 1,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.scale = scale
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task { await loadImage() }
            }
        }
    }
    
    private func loadImage() async {
        guard let url = url, !isLoading else { return }
        
        let cacheKey = url.absoluteString
        
        if let cached = ImageCache.shared.image(for: cacheKey) {
            self.image = cached
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = UIImage(data: data) {
                ImageCache.shared.setImage(downloadedImage, for: cacheKey)
                await MainActor.run {
                    self.image = downloadedImage
                }
            }
        } catch {
            print("Failed to load image: \(error)")
        }
    }
}
