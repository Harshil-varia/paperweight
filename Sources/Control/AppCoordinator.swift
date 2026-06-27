import Foundation
import Combine
import AppKit

class AppCoordinator: ObservableObject {
    private let settingsStore: SettingsStoring
    private let engine: TextureProviding
    private var cancellables = Set<AnyCancellable>()
    private var scheduler: Scheduler!
    private var snoozeTimer: SnoozeTimer!

    @Published private(set) var resolved: ResolvedOverlay
    @Published var settings: Settings {
        didSet {
            recompute()
            // Save settings to store
            try? settingsStore.save(settings)
            // Restart scheduler if schedule changed
            let newSchedule = settings.schedule
            scheduler.stop()
            scheduler.start(with: newSchedule)
        }
    }

    // Phase 4: Input sources that feed into resolve()
    var inputScheduleActive: Bool = false {
        didSet {
            recompute()
        }
    }

    var inputSnoozedUntil: Date? {
        didSet {
            recompute()
        }
    }

    init(
        settingsStore: SettingsStoring = SettingsStore(),
        engine: TextureProviding = TextureEngine(),
        scheduler: Scheduler? = nil,
        snoozeTimer: SnoozeTimer? = nil
    ) {
        self.settingsStore = settingsStore
        self.engine = engine

        let loadedSettings = settingsStore.load()
        self.settings = loadedSettings

        // Set up default settings in UserDefaults
        settingsStore.register(defaults: Settings())

        // Set up scheduler and snooze timer (must be done before using them)
        let tempScheduler = scheduler ?? Scheduler()
        let tempSnoozeTimer = snoozeTimer ?? SnoozeTimer()
        self.scheduler = tempScheduler
        self.snoozeTimer = tempSnoozeTimer

        // Initialize resolved state from loaded settings
        let profile = loadedSettings.selectedProfile
        let inputs = OverlayInputs(
            isEnabled: loadedSettings.isEnabled,
            selectedProfile: profile,
            comfort: loadedSettings.comfort,
            scheduleConfigured: loadedSettings.schedule != .off,
            scheduleActive: false,
            snoozedUntil: nil
        )
        self.resolved = resolve(inputs)

        // Set coordinator reference on scheduler and snooze timer (must be after self is initialized)
        self.scheduler.setCoordinator(self)
        self.snoozeTimer.setCoordinator(self)

        // Start the scheduler
        self.scheduler.start(with: loadedSettings.schedule)

        // Observe wake notification to re-arm scheduler
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onWakeNotification),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        scheduler.stop()
    }

    func recompute() {
        let profile = settings.selectedProfile
        let inputs = OverlayInputs(
            isEnabled: settings.isEnabled,
            selectedProfile: profile,
            comfort: settings.comfort,
            scheduleConfigured: settings.schedule != .off,
            scheduleActive: inputScheduleActive,
            snoozedUntil: inputSnoozedUntil
        )
        let newResolved = resolve(inputs)

        if newResolved != resolved {
            resolved = newResolved
        }
    }

    @objc private func onWakeNotification() {
        // Re-arm the scheduler on wake (timers don't fire if the Mac slept through them)
        scheduler.stop()
        scheduler.start(with: settings.schedule)
    }
}
