import Foundation
import Combine

class AppCoordinator: ObservableObject {
    private let settingsStore: SettingsStoring
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var resolved: ResolvedOverlay
    @Published var settings: Settings {
        didSet {
            recompute()
            // Save settings to store
            try? settingsStore.save(settings)
        }
    }

    init(settingsStore: SettingsStoring = SettingsStore()) {
        self.settingsStore = settingsStore
        let loadedSettings = settingsStore.load()
        self.settings = loadedSettings

        // Set up default settings in UserDefaults
        settingsStore.register(defaults: Settings())

        // Initialize resolved state from loaded settings
        let inputs = OverlayInputs(
            isEnabled: loadedSettings.isEnabled,
            selectedProfileID: loadedSettings.selectedProfileID,
            comfort: loadedSettings.comfort
        )
        self.resolved = resolve(inputs)
    }

    private func recompute() {
        let inputs = OverlayInputs(
            isEnabled: settings.isEnabled,
            selectedProfileID: settings.selectedProfileID,
            comfort: settings.comfort
        )
        let newResolved = resolve(inputs)

        if newResolved != resolved {
            resolved = newResolved
        }
    }
}
