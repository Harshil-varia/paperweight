import XCTest
@testable import Paperweight

final class TileCacheTests: XCTestCase {
    private let cache = TileCache()
    private let generator = CoreImageNoiseGenerator()

    func testCacheStoresAndRetrievesTile() throws {
        let profile = TextureProfile(
            id: "cache-test-1",
            name: "Cache Test 1",
            noiseType: .white,
            tint: 0.0,
            matteLift: 0.1,
            blendMode: .softLight,
            opacityRange: OpacityRange(0.15, 0.30),
            tileSize: 256,
            seed: 42
        )

        let cacheKey = profile.contentHash(scale: 1.0)
        guard let tile = generator.tile(for: profile, scale: 1.0) else {
            XCTFail("Failed to generate tile")
            return
        }

        // Store in cache
        cache.set(cacheKey, value: tile)

        // Retrieve from cache
        let retrieved = cache.get(cacheKey)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.size, tile.size)
    }

    func testCacheKeyDependsOnProfileAndScale() throws {
        let profile1 = TextureProfile(
            id: "cache-test-2",
            name: "Cache Test 2",
            noiseType: .white,
            tint: 0.0,
            matteLift: 0.1,
            blendMode: .softLight,
            opacityRange: OpacityRange(0.15, 0.30),
            tileSize: 256,
            seed: 42
        )

        let profile2 = TextureProfile(
            id: "cache-test-3",
            name: "Cache Test 3",
            noiseType: .white,
            tint: 0.0,
            matteLift: 0.1,
            blendMode: .softLight,
            opacityRange: OpacityRange(0.15, 0.30),
            tileSize: 256,
            seed: 99
        )

        let key1a = profile1.contentHash(scale: 1.0)
        let key1b = profile1.contentHash(scale: 2.0)
        let key2a = profile2.contentHash(scale: 1.0)

        // Keys should be different for different profiles or scales
        XCTAssertNotEqual(key1a, key1b)
        XCTAssertNotEqual(key1a, key2a)
    }

    func testCacheMissReturnsNil() throws {
        let nonexistentKey = "nonexistent-key-xyz"
        let result = cache.get(nonexistentKey)
        XCTAssertNil(result)
    }

    func testCacheCanStoreMultipleTiles() throws {
        let profile1 = TextureProfile(
            id: "multi-1",
            name: "Multi 1",
            noiseType: .white,
            tint: 0.0,
            matteLift: 0.1,
            blendMode: .softLight,
            opacityRange: OpacityRange(0.15, 0.30),
            tileSize: 256,
            seed: 42
        )

        let profile2 = TextureProfile(
            id: "multi-2",
            name: "Multi 2",
            noiseType: .white,
            tint: 0.0,
            matteLift: 0.1,
            blendMode: .softLight,
            opacityRange: OpacityRange(0.15, 0.30),
            tileSize: 256,
            seed: 99
        )

        guard let tile1 = generator.tile(for: profile1, scale: 1.0),
              let tile2 = generator.tile(for: profile2, scale: 1.0) else {
            XCTFail("Failed to generate tiles")
            return
        }

        let key1 = profile1.contentHash(scale: 1.0)
        let key2 = profile2.contentHash(scale: 1.0)

        cache.set(key1, value: tile1)
        cache.set(key2, value: tile2)

        let retrieved1 = cache.get(key1)
        let retrieved2 = cache.get(key2)

        XCTAssertNotNil(retrieved1)
        XCTAssertNotNil(retrieved2)
        XCTAssertEqual(retrieved1?.size, tile1.size)
        XCTAssertEqual(retrieved2?.size, tile2.size)
    }
}
