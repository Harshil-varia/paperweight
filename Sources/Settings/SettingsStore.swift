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
            print("Failed to decode settings: \(error)")
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

        // v1 → v2: add schedule field (default to .off if not present)
        if result.schemaVersion < 2 {
            result.schedule = .off
            result.schemaVersion = 2
        }

        return result
    }
}
