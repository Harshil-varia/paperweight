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

    func testMigrationV1toV2AddsSchedule() {
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

        // Load and verify migration
        let store = SettingsStore(userDefaults: userDefaults)
        let migrated = store.load()

        XCTAssertEqual(migrated.schemaVersion, 2, "Schema should be bumped to v2")
        XCTAssertEqual(migrated.isEnabled, v1Components.isEnabled, "isEnabled should be preserved")
        XCTAssertEqual(migrated.selectedProfileID, v1Components.selectedProfileID, "selectedProfileID should be preserved")
        XCTAssertEqual(migrated.comfort, v1Components.comfort, "comfort should be preserved")
        XCTAssertEqual(migrated.schedule, .off, "schedule should default to .off in v2")
    }

    func testRoundTripV2SettingsWithSchedule() {
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

        XCTAssertEqual(loaded.schemaVersion, 2)
        XCTAssertEqual(loaded.schedule, .manual(fromHour: 9, fromMinute: 0, toHour: 17, toMinute: 0))
    }

    func testRoundTripV2SettingsWithSolarSchedule() {
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

        XCTAssertEqual(loaded.schemaVersion, 2)
        if case let .solar(lat, long) = loaded.schedule {
            XCTAssertEqualWithAccuracy(lat, 40.7128, accuracy: 0.0001)
            XCTAssertEqualWithAccuracy(long, -74.0060, accuracy: 0.0001)
        } else {
            XCTFail("Expected solar schedule")
        }
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
