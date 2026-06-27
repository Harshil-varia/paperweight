import Foundation
import Combine

class AppCoordinator: ObservableObject {
    private let settingsStore: SettingsStoring
    private let engine: TextureProviding
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var resolved: ResolvedOverlay
    @Published var settings: Settings {
        didSet {
            recompute()
            // Save settings to store
            try? settingsStore.save(settings)
        }
    }

    init(
        settingsStore: SettingsStoring = SettingsStore(),
        engine: TextureProviding = TextureEngine()
    ) {
        self.settingsStore = settingsStore
        self.engine = engine

        let loadedSettings = settingsStore.load()
        self.settings = loadedSettings

        // Set up default settings in UserDefaults
        settingsStore.register(defaults: Settings())

        // Initialize resolved state from loaded settings
        let profile = loadedSettings.selectedProfile
        let inputs = OverlayInputs(
            isEnabled: loadedSettings.isEnabled,
            selectedProfile: profile,
            comfort: loadedSettings.comfort
        )
        self.resolved = resolve(inputs)
    }

    private func recompute() {
        let profile = settings.selectedProfile
        let inputs = OverlayInputs(
            isEnabled: settings.isEnabled,
            selectedProfile: profile,
            comfort: settings.comfort
        )
        let newResolved = resolve(inputs)

        if newResolved != resolved {
            resolved = newResolved
        }
    }
}
