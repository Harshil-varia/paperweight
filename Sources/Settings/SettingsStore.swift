import Foundation

protocol SettingsStoring {
    func load() -> Settings
    func save(_ settings: Settings) throws
    func register(defaults: Settings)
}

class SettingsStore: SettingsStoring {
    private let userDefaults: UserDefaults
    private let key = "com.humanlayer.paperweight.settings"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> Settings {
        guard let data = userDefaults.data(forKey: key) else {
            return Settings()
        }

        do {
            let decoder = JSONDecoder()
            let settings = try decoder.decode(Settings.self, from: data)
            return migrate(settings)
        } catch {
            // Resilient decoding means this only triggers on genuinely corrupt
            // data, not on older blobs missing newer fields. Surface it rather
            // than silently resetting all preferences with no trace.
            Log.settings.error("Failed to decode settings, using defaults: \(String(describing: error))")
            return Settings()
        }
    }

    func save(_ settings: Settings) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        userDefaults.set(data, forKey: key)
    }

    func register(defaults: Settings) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(defaults) else { return }

        userDefaults.register(defaults: [
            key: data
        ])
    }

    private func migrate(_ settings: Settings) -> Settings {
        var result = settings

        // Fields added across versions (schedule, ambient inputs) are filled by
        // Settings' resilient decoder when missing, so migration must NEVER
        // overwrite decoded values — doing so previously wiped users' custom
        // exclusions on upgrade. Earlier builds also auto-seeded browsers
        // (Safari/Chrome/Finder) as exclusions, which turned the overlay OFF
        // during normal browsing; the default is now empty (opt-in).
        if result.schemaVersion < Settings.currentSchemaVersion {
            result.schemaVersion = Settings.currentSchemaVersion
        }

        return result
    }
}
