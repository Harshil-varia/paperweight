import XCTest
@testable import Paperweight

final class PresetLibraryTests: XCTestCase {
    func testAllPresetsAreUnique() throws {
        let presets = TextureProfile.flatPresets
        let ids = presets.map { $0.id }
        let uniqueIds = Set(ids)

        XCTAssertEqual(ids.count, uniqueIds.count, "All preset IDs should be unique")
        XCTAssertEqual(presets.count, 12, "Should have exactly 12 presets")
    }

    func testAllPresetsHaveValidOpacityRanges() throws {
        for preset in TextureProfile.flatPresets {
            XCTAssertGreaterThanOrEqual(preset.opacityRange.minOpacity, 0.0, "\(preset.name): min opacity must be >= 0")
            XCTAssertLessThanOrEqual(preset.opacityRange.maxOpacity, 1.0, "\(preset.name): max opacity must be <= 1")
            XCTAssertLessThanOrEqual(
                preset.opacityRange.minOpacity,
                preset.opacityRange.maxOpacity,
                "\(preset.name): min opacity must be <= max opacity"
            )
        }
    }

    func testAllPresetsHaveValidTileSizes() throws {
        let validSizes = Set([256, 512, 1024])
        for preset in TextureProfile.flatPresets {
            XCTAssertTrue(validSizes.contains(preset.tileSize), "\(preset.name): tile size must be 256, 512, or 1024")
        }
    }

    func testAllPresetsHaveValidNoiseTypes() throws {
        for preset in TextureProfile.flatPresets {
            let noiseType = preset.noiseType
            XCTAssertTrue(
                [.white, .value, .perlin, .simplex, .fbm, .ridged, .worley].contains(noiseType),
                "\(preset.name): noise type is invalid"
            )
        }
    }

    func testAllPresetsHaveValidBlendModes() throws {
        for preset in TextureProfile.flatPresets {
            let blendMode = preset.blendMode
            XCTAssertTrue(
                [.softLight, .multiply, .screen, .overlay].contains(blendMode),
                "\(preset.name): blend mode is invalid"
            )
        }
    }

    func testAllPresetsHaveValidTints() throws {
        for preset in TextureProfile.flatPresets {
            XCTAssertGreaterThanOrEqual(preset.tint, -1.0, "\(preset.name): tint must be >= -1.0")
            XCTAssertLessThanOrEqual(preset.tint, 1.0, "\(preset.name): tint must be <= 1.0")
        }
    }

    func testAllPresetsHaveValidMatteLifts() throws {
        for preset in TextureProfile.flatPresets {
            XCTAssertGreaterThanOrEqual(preset.matteLift, 0.0, "\(preset.name): matte lift must be >= 0.0")
            XCTAssertLessThanOrEqual(preset.matteLift, 1.0, "\(preset.name): matte lift must be <= 1.0")
        }
    }

    func testPresetLookupByID() throws {
        for preset in TextureProfile.flatPresets {
            let found = TextureProfile.preset(withID: preset.id)
            XCTAssertNotNil(found, "Should find preset with ID: \(preset.id)")
            XCTAssertEqual(found?.id, preset.id, "Looked up preset should match original")
        }
    }

    func testInvalidPresetLookup() throws {
        let notFound = TextureProfile.preset(withID: "does-not-exist")
        XCTAssertNil(notFound, "Invalid preset ID should return nil")
    }

    func testNoiseTypeStableCodes() throws {
        let stableCodes = Set([
            NoiseType.white.stableCode,
            NoiseType.value.stableCode,
            NoiseType.perlin.stableCode,
            NoiseType.simplex.stableCode,
            NoiseType.fbm.stableCode,
            NoiseType.ridged.stableCode,
            NoiseType.worley.stableCode
        ])

        XCTAssertEqual(stableCodes.count, 7, "All noise types should have unique stable codes")
    }

    func testComfortRowPresetsExist() throws {
        let comfortRow = TextureProfile.allPresets[0]
        XCTAssertEqual(comfortRow.count, 4, "Comfort row should have 4 presets")

        let ids = comfortRow.map { $0.id }
        XCTAssertTrue(ids.contains("eink-calm"), "E-Ink Calm should be in comfort row")
        XCTAssertTrue(ids.contains("classic-matte"), "Classic Matte should be in comfort row")
        XCTAssertTrue(ids.contains("vellum-mist"), "Vellum Mist should be in comfort row")
        XCTAssertTrue(ids.contains("blueprint"), "Blueprint should be in comfort row")
    }

    func testCharacterRowPresetsExist() throws {
        let characterRow = TextureProfile.allPresets[1]
        XCTAssertEqual(characterRow.count, 8, "Character row should have 8 presets")

        let ids = characterRow.map { $0.id }
        XCTAssertTrue(ids.contains("whisper-weave"), "Whisper Weave should be in character row")
        XCTAssertTrue(ids.contains("sunbaked-parchment"), "Sunbaked Parchment should be in character row")
        XCTAssertTrue(ids.contains("saddle-linen"), "Saddle Linen should be in character row")
        XCTAssertTrue(ids.contains("painters-press"), "Painter's Press should be in character row")
        XCTAssertTrue(ids.contains("mulberry-veil"), "Mulberry Veil should be in character row")
        XCTAssertTrue(ids.contains("monastic-felt"), "Monastic Felt should be in character row")
        XCTAssertTrue(ids.contains("carbon-ledger"), "Carbon Ledger should be in character row")
        XCTAssertTrue(ids.contains("riso-grain"), "Riso Grain should be in character row")
    }

    func testPresetCodable() throws {
        let preset = TextureProfile.eInkCalm
        let encoder = JSONEncoder()
        let data = try encoder.encode(preset)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TextureProfile.self, from: data)

        XCTAssertEqual(decoded, preset, "Preset should round-trip through JSON encoding")
    }

    func testSettingsPresetResolution() throws {
        var settings = Settings()

        settings.selectedProfileID = "classic-matte"
        XCTAssertEqual(settings.selectedProfile.id, "classic-matte")

        settings.selectedProfileID = "mulberry-veil"
        XCTAssertEqual(settings.selectedProfile.id, "mulberry-veil")

        // Invalid preset should fall back to default
        settings.selectedProfileID = "invalid-preset"
        XCTAssertEqual(settings.selectedProfile.id, "eink-calm")
    }
}
