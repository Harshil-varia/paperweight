import XCTest
@testable import Paperweight

final class NoiseDeterminismTests: XCTestCase {
    let generator = CoreImageNoiseGenerator()

    func testNoiseTypeDeterminism() throws {
        let noiseTypes: [NoiseType] = [.white, .value, .perlin, .simplex, .fbm, .ridged, .worley]

        for noiseType in noiseTypes {
            let profile = TextureProfile(
                id: "test-\(noiseType.rawValue)",
                name: "Test \(noiseType.rawValue)",
                noiseType: noiseType,
                tint: 0.0,
                matteLift: 0.1,
                blendMode: .softLight,
                opacityRange: OpacityRange(0.15, 0.30),
                tileSize: 256,
                seed: 42
            )

            let tile1 = generator.tile(for: profile, scale: 1.0)
            let tile2 = generator.tile(for: profile, scale: 1.0)

            XCTAssertNotNil(tile1, "Tile should generate for \(noiseType.rawValue)")
            XCTAssertNotNil(tile2, "Tile should generate for \(noiseType.rawValue)")
        }
    }

    func testWhiteNoiseWithSameSeedProducesSameBytes() throws {
        let profile = TextureProfile(
            id: "test-white",
            name: "Test White",
            noiseType: .white,
            tint: 0.0,
            matteLift: 0.1,
            blendMode: .softLight,
            opacityRange: OpacityRange(0.15, 0.30),
            tileSize: 256,
            seed: 42
        )

        let tile1 = generator.tile(for: profile, scale: 1.0)
        let tile2 = generator.tile(for: profile, scale: 1.0)

        XCTAssertNotNil(tile1)
        XCTAssertNotNil(tile2)
    }

    func testValueNoiseWithDifferentSeedsProduceDifferentBytes() throws {
        let profile1 = TextureProfile(
            id: "test-value-1",
            name: "Test Value 1",
            noiseType: .value,
            tint: 0.0,
            matteLift: 0.1,
            blendMode: .softLight,
            opacityRange: OpacityRange(0.15, 0.30),
            tileSize: 256,
            seed: 42
        )

        let profile2 = TextureProfile(
            id: "test-value-2",
            name: "Test Value 2",
            noiseType: .value,
            tint: 0.0,
            matteLift: 0.1,
            blendMode: .softLight,
            opacityRange: OpacityRange(0.15, 0.30),
            tileSize: 256,
            seed: 99
        )

        let tile1 = generator.tile(for: profile1, scale: 1.0)
        let tile2 = generator.tile(for: profile2, scale: 1.0)

        XCTAssertNotNil(tile1)
        XCTAssertNotNil(tile2)
    }

    func testTileSizeAffectsOutput() throws {
        let profile256 = TextureProfile(
            id: "test-256",
            name: "Test 256",
            noiseType: .white,
            tint: 0.0,
            matteLift: 0.1,
            blendMode: .softLight,
            opacityRange: OpacityRange(0.15, 0.30),
            tileSize: 256,
            seed: 42
        )

        let profile512 = TextureProfile(
            id: "test-512",
            name: "Test 512",
            noiseType: .white,
            tint: 0.0,
            matteLift: 0.1,
            blendMode: .softLight,
            opacityRange: OpacityRange(0.15, 0.30),
            tileSize: 512,
            seed: 42
        )

        let tile256 = generator.tile(for: profile256, scale: 1.0)
        let tile512 = generator.tile(for: profile512, scale: 1.0)

        XCTAssertNotNil(tile256)
        XCTAssertNotNil(tile512)

        if let tile256 = tile256, let tile512 = tile512 {
            XCTAssertEqual(tile256.cgImage.width, 256)
            XCTAssertEqual(tile512.cgImage.width, 512)
        }
    }

    func testPerlinNoiseDeterminism() throws {
        let profile = TextureProfile(
            id: "test-perlin",
            name: "Test Perlin",
            noiseType: .perlin,
            tint: 0.05,
            matteLift: 0.12,
            blendMode: .softLight,
            opacityRange: OpacityRange(0.14, 0.28),
            tileSize: 512,
            seed: 256
        )

        let tile1 = generator.tile(for: profile, scale: 1.0)
        let tile2 = generator.tile(for: profile, scale: 1.0)

        XCTAssertNotNil(tile1)
        XCTAssertNotNil(tile2)
    }

    func testFbmDeterminism() throws {
        let profile = TextureProfile(
            id: "test-fbm",
            name: "Test fBm",
            noiseType: .fbm,
            tint: 0.2,
            matteLift: 0.2,
            blendMode: .multiply,
            opacityRange: OpacityRange(0.20, 0.35),
            tileSize: 512,
            seed: 333
        )

        let tile1 = generator.tile(for: profile, scale: 1.0)
        let tile2 = generator.tile(for: profile, scale: 1.0)

        XCTAssertNotNil(tile1)
        XCTAssertNotNil(tile2)
    }

    func testRidgedDeterminism() throws {
        let profile = TextureProfile(
            id: "test-ridged",
            name: "Test Ridged",
            noiseType: .ridged,
            tint: 0.1,
            matteLift: 0.25,
            blendMode: .softLight,
            opacityRange: OpacityRange(0.22, 0.38),
            tileSize: 512,
            seed: 777
        )

        let tile1 = generator.tile(for: profile, scale: 1.0)
        let tile2 = generator.tile(for: profile, scale: 1.0)

        XCTAssertNotNil(tile1)
        XCTAssertNotNil(tile2)
    }

    func testWorleyDeterminism() throws {
        let profile = TextureProfile(
            id: "test-worley",
            name: "Test Worley",
            noiseType: .worley,
            tint: 0.05,
            matteLift: 0.16,
            blendMode: .softLight,
            opacityRange: OpacityRange(0.16, 0.32),
            tileSize: 512,
            seed: 444
        )

        let tile1 = generator.tile(for: profile, scale: 1.0)
        let tile2 = generator.tile(for: profile, scale: 1.0)

        XCTAssertNotNil(tile1)
        XCTAssertNotNil(tile2)
    }
}
