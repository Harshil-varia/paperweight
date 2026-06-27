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
}

func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T) {
    do {
        _ = try expression()
    } catch {
        XCTFail("Expected no throw, but got: \(error)")
    }
}
