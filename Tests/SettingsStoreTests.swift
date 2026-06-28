import XCTest
@testable import Paperweight

class SettingsStoreTests: XCTestCase {
    var suiteName: String!
    var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test-settings-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        // Also remove registered defaults
        userDefaults?.removeObject(forKey: "com.humanlayer.paperweight.settings")
        userDefaults = nil
        super.tearDown()
    }

    func testRoundTripSettingsOverUserDefaults() {
        let store = SettingsStore(userDefaults: userDefaults)
        let original = Settings(
            isEnabled: true,
            selectedProfileID: "test-profile",
            comfort: 0.75
        )

        try? store.save(original)
        let loaded = store.load()

        XCTAssertEqual(loaded.isEnabled, original.isEnabled)
        XCTAssertEqual(loaded.selectedProfileID, original.selectedProfileID)
        XCTAssertEqual(loaded.comfort, original.comfort)
    }

    func testDefaultSeedingOnFirstRun() {
        let store = SettingsStore(userDefaults: userDefaults)
        let defaults = Settings(
            isEnabled: false,
            selectedProfileID: "seeded-profile",
            comfort: 0.3
        )

        store.register(defaults: defaults)

        // Load without saving first
        let loaded = store.load()

        // Should get the registered defaults
        XCTAssertEqual(loaded.isEnabled, false)
        XCTAssertEqual(loaded.selectedProfileID, "seeded-profile")
        XCTAssertEqual(loaded.comfort, 0.3)
    }


    func testSaveThrowsOnEncodingFailure() {
        // This is a basic happy-path test; encoding should always succeed for Settings
        let store = SettingsStore(userDefaults: userDefaults)
        let settings = Settings()

        XCTAssertNoThrow(try store.save(settings))
    }

    // MARK: - Phase 4: Migration tests

    func testMigrationV1toV2toV3AddsScheduleThenAmbient() {
        // Manually create and save a v1 settings blob
        var v1Components = Settings(schemaVersion: 1)
        v1Components.isEnabled = true
        v1Components.selectedProfileID = "eink-calm"
        v1Components.comfort = 0.5
        v1Components.schedule = .off // This field shouldn't exist in v1, but we set it for testing

        // Encode as v1
        let encoder = JSONEncoder()
        guard let v1Data = try? encoder.encode(v1Components) else {
            XCTFail("Failed to encode v1 settings")
            return
        }

        // Manually insert the v1 blob into UserDefaults
        userDefaults.set(v1Data, forKey: "com.humanlayer.paperweight.settings")

        // Load and verify migration (v1 -> v2 -> v3)
        let store = SettingsStore(userDefaults: userDefaults)
        let migrated = store.load()

        // After migration, schemaVersion should be 3 (v1->v2->v3)
        XCTAssertEqual(migrated.schemaVersion, 3, "Schema should be bumped to v3")
        XCTAssertEqual(migrated.isEnabled, v1Components.isEnabled, "isEnabled should be preserved")
        XCTAssertEqual(migrated.selectedProfileID, v1Components.selectedProfileID, "selectedProfileID should be preserved")
        XCTAssertEqual(migrated.comfort, v1Components.comfort, "comfort should be preserved")
        XCTAssertEqual(migrated.schedule, .off, "schedule should default to .off in v2")
        // Verify Phase 5 fields are initialized
        XCTAssertTrue(migrated.exclusions.isEmpty, "exclusions default to empty (opt-in, no browser auto-hide)")
        XCTAssertFalse(migrated.pauseOnBattery, "pauseOnBattery should default to false")
        XCTAssertFalse(migrated.launchAtLogin, "launchAtLogin should default to false")
    }

    func testRoundTripV2SettingsWithScheduleMigratestoV3() {
        let store = SettingsStore(userDefaults: userDefaults)
        let original = Settings(
            schemaVersion: 2,
            isEnabled: true,
            selectedProfileID: "eink-calm",
            comfort: 0.6,
            schedule: .manual(fromHour: 9, fromMinute: 0, toHour: 17, toMinute: 0)
        )

        try? store.save(original)
        let loaded = store.load()

        // After loading v2, it should be migrated to v3
        XCTAssertEqual(loaded.schemaVersion, 3, "v2 should be auto-migrated to v3")
        XCTAssertEqual(loaded.schedule, .manual(fromHour: 9, fromMinute: 0, toHour: 17, toMinute: 0))
        // Verify Phase 5 fields are initialized
        XCTAssertTrue(loaded.exclusions.isEmpty, "exclusions default to empty (opt-in)")
    }

    func testRoundTripV2SettingsWithSolarScheduleMigratestoV3() {
        let store = SettingsStore(userDefaults: userDefaults)
        let original = Settings(
            schemaVersion: 2,
            isEnabled: true,
            selectedProfileID: "classic-matte",
            comfort: 0.4,
            schedule: .solar(latitude: 40.7128, longitude: -74.0060)
        )

        try? store.save(original)
        let loaded = store.load()

        // After loading v2, it should be migrated to v3
        XCTAssertEqual(loaded.schemaVersion, 3, "v2 should be auto-migrated to v3")
        if case let .solar(lat, long) = loaded.schedule {
            XCTAssertEqualWithAccuracy(lat, 40.7128, accuracy: 0.0001)
            XCTAssertEqualWithAccuracy(long, -74.0060, accuracy: 0.0001)
        } else {
            XCTFail("Expected solar schedule")
        }
        // Verify Phase 5 fields are initialized
        XCTAssertTrue(loaded.exclusions.isEmpty, "exclusions default to empty (opt-in)")
    }

    // MARK: - Phase 5: v2→v3 Migration Tests

    func testMigrationV2toV3AddsAmbientFields() {
        // Manually create and save a v2 settings blob without Phase 5 fields
        var v2Components = Settings(
            schemaVersion: 2,
            isEnabled: true,
            selectedProfileID: "eink-calm",
            comfort: 0.6,
            schedule: .manual(fromHour: 9, fromMinute: 0, toHour: 17, toMinute: 0)
        )

        // Encode as v2
        let encoder = JSONEncoder()
        guard let v2Data = try? encoder.encode(v2Components) else {
            XCTFail("Failed to encode v2 settings")
            return
        }

        // Manually insert the v2 blob into UserDefaults
        userDefaults.set(v2Data, forKey: "com.humanlayer.paperweight.settings")

        // Load and verify migration
        let store = SettingsStore(userDefaults: userDefaults)
        let migrated = store.load()

        XCTAssertEqual(migrated.schemaVersion, 3, "Schema should be bumped to v3")
        XCTAssertEqual(migrated.isEnabled, v2Components.isEnabled, "isEnabled should be preserved")
        XCTAssertEqual(migrated.selectedProfileID, v2Components.selectedProfileID, "selectedProfileID should be preserved")
        XCTAssertEqual(migrated.comfort, v2Components.comfort, "comfort should be preserved")
        XCTAssertEqual(migrated.schedule, v2Components.schedule, "schedule should be preserved")

        // Verify Phase 5 fields are initialized
        XCTAssertTrue(migrated.exclusions.isEmpty, "exclusions default to empty (opt-in, no browser auto-hide)")
        XCTAssertFalse(migrated.pauseOnBattery, "pauseOnBattery should default to false")
        XCTAssertFalse(migrated.launchAtLogin, "launchAtLogin should default to false")
        XCTAssertEqual(migrated.reduceTransparencyResponse, .stepDown, "reduceTransparencyResponse should default to stepDown")
        XCTAssertEqual(migrated.perDisplay.count, 0, "perDisplay should start empty")
    }

    func testMigrationV2toV3PreservesExistingExclusions() {
        // Create a v3 settings blob with custom exclusions
        var v3Original = Settings(
            schemaVersion: 3,
            isEnabled: true,
            selectedProfileID: "classic-matte",
            comfort: 0.7,
            schedule: .off,
            exclusions: ["com.custom.app", "com.example.tool"],
            pauseOnBattery: true,
            launchAtLogin: true,
            reduceTransparencyResponse: .flatMatte
        )

        let encoder = JSONEncoder()
        guard let v3Data = try? encoder.encode(v3Original) else {
            XCTFail("Failed to encode v3 settings")
            return
        }

        userDefaults.set(v3Data, forKey: "com.humanlayer.paperweight.settings")

        let store = SettingsStore(userDefaults: userDefaults)
        let loaded = store.load()

        XCTAssertEqual(loaded.schemaVersion, 3)
        XCTAssertTrue(loaded.exclusions.contains("com.custom.app"))
        XCTAssertTrue(loaded.exclusions.contains("com.example.tool"))
        XCTAssertTrue(loaded.pauseOnBattery)
        XCTAssertTrue(loaded.launchAtLogin)
        XCTAssertEqual(loaded.reduceTransparencyResponse, .flatMatte)
    }

    func testRoundTripV3SettingsWithPerDisplay() {
        let store = SettingsStore(userDefaults: userDefaults)
        let perDisplay: [DisplayID: DisplaySetting] = [
            "0": DisplaySetting(isEnabled: true),
            "1": DisplaySetting(isEnabled: false)
        ]
        let original = Settings(
            schemaVersion: 3,
            isEnabled: true,
            selectedProfileID: "eink-calm",
            comfort: 0.5,
            schedule: .off,
            exclusions: ["com.apple.Safari"],
            pauseOnBattery: true,
            launchAtLogin: false,
            reduceTransparencyResponse: .stepDown,
            perDisplay: perDisplay
        )

        try? store.save(original)
        let loaded = store.load()

        XCTAssertEqual(loaded.schemaVersion, 3)
        XCTAssertEqual(loaded.perDisplay.count, 2)
        XCTAssertTrue(loaded.perDisplay["0"]?.isEnabled ?? false)
        XCTAssertFalse(loaded.perDisplay["1"]?.isEnabled ?? true)
        XCTAssertTrue(loaded.exclusions.contains("com.apple.Safari"))
    }

    func testMigrationDoesNotSeedBrowserExclusions() {
        // Migration must NOT auto-add browsers as exclusions — that would hide
        // the overlay during normal browsing. The default is empty (opt-in).
        let v2Settings = Settings(schemaVersion: 2)
        let encoder = JSONEncoder()
        guard let v2Data = try? encoder.encode(v2Settings) else {
            XCTFail("Failed to encode v2 settings")
            return
        }

        userDefaults.set(v2Data, forKey: "com.humanlayer.paperweight.settings")

        let store = SettingsStore(userDefaults: userDefaults)
        let migrated = store.load()

        XCTAssertTrue(migrated.exclusions.isEmpty, "migration must not seed exclusions")
        XCTAssertEqual(migrated.schemaVersion, 3)
    }

    func testDecodingOlderBlobMissingFieldsKeepsPresentValuesAndDefaultsRest() {
        // An old build's JSON that predates several fields must decode without
        // throwing, preserving the values it DOES have and defaulting the rest —
        // rather than failing to decode and wiping every preference.
        let legacyJSON = """
        { "schemaVersion": 1, "isEnabled": false, "selectedProfileID": "blueprint", "comfort": 0.83 }
        """.data(using: .utf8)!
        userDefaults.set(legacyJSON, forKey: "com.humanlayer.paperweight.settings")

        let store = SettingsStore(userDefaults: userDefaults)
        let loaded = store.load()

        // Present fields preserved
        XCTAssertFalse(loaded.isEnabled)
        XCTAssertEqual(loaded.selectedProfileID, "blueprint")
        XCTAssertEqual(loaded.comfort, 0.83, accuracy: 0.001)
        // Missing fields defaulted (not a decode failure → not reset to ALL defaults)
        XCTAssertEqual(loaded.schedule, .off)
        XCTAssertTrue(loaded.exclusions.isEmpty)
        XCTAssertEqual(loaded.reduceTransparencyResponse, .stepDown)
        XCTAssertEqual(loaded.schemaVersion, 3, "stamped to current schema")
    }
}

func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T) {
    do {
        _ = try expression()
    } catch {
        XCTFail("Expected no throw, but got: \(error)")
    }
}

extension XCTestCase {
    func XCTAssertEqualWithAccuracy(_ expression1: Double, _ expression2: Double, accuracy: Double, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            abs(expression1 - expression2) <= accuracy,
            message(),
            file: file,
            line: line
        )
    }
}
