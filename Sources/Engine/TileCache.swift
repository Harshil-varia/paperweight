import Foundation
import AppKit

class TileCache: @unchecked Sendable {
    // In-memory hot cache
    private var memoryCache: [String: TileImage] = [:]
    private let memoryCacheLock = NSLock()

    // On-disk warm cache location
    private let diskCacheURL: URL

    init() {
        // Cache directory: ~/Library/Caches/com.humanlayer.paperweight/
        let cachePaths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let appCacheDir = cachePaths[0].appendingPathComponent("com.humanlayer.paperweight", isDirectory: true)

        self.diskCacheURL = appCacheDir.appendingPathComponent("tiles", isDirectory: true)

        // Ensure cache directory exists
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    func get(_ key: String) -> TileImage? {
        // Check hot memory cache first
        memoryCacheLock.lock()
        defer { memoryCacheLock.unlock() }

        if let cached = memoryCache[key] {
            return cached
        }

        // Try warm disk cache
        if let diskTile = loadFromDisk(key) {
            // Promote to memory cache
            memoryCache[key] = diskTile
            return diskTile
        }

        return nil
    }

    func set(_ key: String, value: TileImage) {
        // Store in memory cache
        memoryCacheLock.lock()
        memoryCache[key] = value
        memoryCacheLock.unlock()

        // Store on disk asynchronously
        let diskCacheURL = self.diskCacheURL
        DispatchQueue.global(qos: .background).async { [diskCacheURL] in
            self.saveToDisk(key, tile: value, cacheURL: diskCacheURL)
        }
    }

    private func loadFromDisk(_ key: String) -> TileImage? {
        let fileURL = diskCacheURL.appendingPathComponent(key + ".png")

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let size = CGSize(width: cgImage.width, height: cgImage.height)
        return TileImage(cgImage: cgImage, size: size)
    }

    private func saveToDisk(_ key: String, tile: TileImage, cacheURL: URL) {
        let fileURL = cacheURL.appendingPathComponent(key + ".png")

        // Convert CGImage to PNG data
        guard let tiffData = NSImage(cgImage: tile.cgImage, size: .zero).tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return
        }

        try? pngData.write(to: fileURL)
    }
}
