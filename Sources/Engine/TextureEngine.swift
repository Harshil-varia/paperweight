import Foundation
import AppKit

// MARK: - TileImage

/// A generated noise tile backed by a CGImage
struct TileImage {
    let cgImage: CGImage
    let size: CGSize

    init(cgImage: CGImage, size: CGSize) {
        self.cgImage = cgImage
        self.size = size
    }
}

// MARK: - TextureGenerating Protocol

protocol TextureGenerating {
    /// Generate a seamless tile for the given profile at the specified scale
    /// Pure function: same inputs → identical bytes
    func tile(for profile: TextureProfile, scale: CGFloat) -> TileImage?
}

// MARK: - TextureProviding Protocol

protocol TextureProviding {
    /// Get or generate a tile, using cache when available
    func tile(for profile: TextureProfile, scale: CGFloat) -> TileImage?
}

// MARK: - TextureEngine

class TextureEngine: TextureProviding {
    private let cache: TileCache
    private let primaryGenerator: TextureGenerating
    private let fallbackGenerator: TextureGenerating

    init(cache: TileCache? = nil) {
        self.cache = cache ?? TileCache()

        // Primary: Metal noise generator
        self.primaryGenerator = MetalNoiseGenerator()

        // Fallback: Core Image / CPU-safe generator
        self.fallbackGenerator = CoreImageNoiseGenerator()
    }

    func tile(for profile: TextureProfile, scale: CGFloat) -> TileImage? {
        let cacheKey = profile.contentHash(scale: scale)

        // Check cache first
        if let cached = cache.get(cacheKey) {
            return cached
        }

        // Try primary (Metal) generator
        if let tile = primaryGenerator.tile(for: profile, scale: scale) {
            cache.set(cacheKey, value: tile)
            return tile
        }

        // Fall back to Core Image
        if let tile = fallbackGenerator.tile(for: profile, scale: scale) {
            cache.set(cacheKey, value: tile)
            return tile
        }

        return nil
    }
}
