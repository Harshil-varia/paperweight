import Foundation
import Combine
import AppKit

class AppCoordinator: ObservableObject {
    private let settingsStore: SettingsStoring
    private let engine: TextureProviding
    private var cancellables = Set<AnyCancellable>()
    private var scheduler: Scheduler!
    private var snoozeTimer: SnoozeTimer!

    // Phase 5: Ambient input monitors
    private var exclusionService: ExclusionService?
    private var powerMonitor: PowerMonitor?
    private var reduceTransparencyMonitor: ReduceTransparencyMonitor?
    private var launchAtLoginService: LaunchAtLoginService?

    @Published private(set) var resolved: ResolvedOverlay
    @Published var settings: Settings {
        didSet {
            recompute()
            // Persist; surface failures instead of silently dropping them.
            do {
                try settingsStore.save(settings)
            } catch {
                Log.settings.error("Failed to save settings: \(String(describing: error))")
            }
            // Restart scheduler only when the schedule actually changed, so
            // unrelated setting tweaks (comfort, texture, snooze feedback) don't
            // thrash the timer.
            if settings.schedule != oldValue.schedule {
                scheduler.stop()
                scheduler.start(with: settings.schedule)
            }
        }
    }

    /// Run a block on the main thread, immediately if already there. Used by
    /// background callers (scheduler, snooze timer) so @Published mutations and
    /// the resulting SwiftUI updates never happen off the main thread.
    static func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
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

    // Phase 5: Ambient input sources
    var inputExcludedAppFrontmost: Bool = false {
        didSet {
            recompute()
        }
    }

    var inputOnBattery: Bool = false {
        didSet {
            recompute()
        }
    }

    var inputReduceTransparency: Bool = false {
        didSet {
            recompute()
        }
    }

    init(
        settingsStore: SettingsStoring = SettingsStore(),
        engine: TextureProviding = TextureEngine(),
        scheduler: Scheduler? = nil,
        snoozeTimer: SnoozeTimer? = nil,
        exclusionService: ExclusionService? = nil,
        powerMonitor: PowerMonitor? = nil,
        reduceTransparencyMonitor: ReduceTransparencyMonitor? = nil,
        launchAtLoginService: LaunchAtLoginService? = nil
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

        // Set up ambient monitors
        let tempExclusionService = exclusionService ?? ExclusionService()
        let tempPowerMonitor = powerMonitor ?? PowerMonitor()
        let tempReduceTransparencyMonitor = reduceTransparencyMonitor ?? ReduceTransparencyMonitor()
        let tempLaunchAtLoginService = launchAtLoginService ?? LaunchAtLoginService()
        self.exclusionService = tempExclusionService
        self.powerMonitor = tempPowerMonitor
        self.reduceTransparencyMonitor = tempReduceTransparencyMonitor
        self.launchAtLoginService = tempLaunchAtLoginService

        // Initialize resolved state from loaded settings
        let profile = loadedSettings.selectedProfile
        let inputs = OverlayInputs(
            isEnabled: loadedSettings.isEnabled,
            selectedProfile: profile,
            comfort: loadedSettings.comfort,
            scheduleConfigured: loadedSettings.schedule != .off,
            scheduleActive: false,
            snoozedUntil: nil,
            excludedAppFrontmost: false,
            onBattery: false,
            reduceTransparency: false,
            pauseOnBattery: loadedSettings.pauseOnBattery,
            reduceTransparencyResponse: loadedSettings.reduceTransparencyResponse,
            perDisplay: loadedSettings.perDisplay
        )
        self.resolved = resolve(inputs)

        // Set coordinator reference on scheduler and snooze timer (must be after self is initialized)
        self.scheduler.setCoordinator(self)
        self.snoozeTimer.setCoordinator(self)

        // Set coordinator reference on ambient monitors
        tempExclusionService.coordinator = self
        tempPowerMonitor.coordinator = self
        tempReduceTransparencyMonitor.coordinator = self

        // Start the scheduler and monitors
        self.scheduler.start(with: loadedSettings.schedule)
        tempExclusionService.start()
        tempPowerMonitor.start()
        tempReduceTransparencyMonitor.start()

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
        exclusionService?.stop()
        powerMonitor?.stop()
        reduceTransparencyMonitor?.stop()
    }

    // MARK: - Snooze

    /// Whether the overlay is currently snoozed (silenced until a future time).
    var isSnoozed: Bool {
        guard let until = inputSnoozedUntil else { return false }
        return Date() < until
    }

    /// Silence the overlay for the given number of minutes.
    func snooze(minutes: Int) {
        snoozeTimer.start(minutes: minutes)
    }

    /// End an active snooze immediately.
    func endSnooze() {
        snoozeTimer.cancel()
    }

    func recompute() {
        let profile = settings.selectedProfile
        let inputs = OverlayInputs(
            isEnabled: settings.isEnabled,
            selectedProfile: profile,
            comfort: settings.comfort,
            scheduleConfigured: settings.schedule != .off,
            scheduleActive: inputScheduleActive,
            snoozedUntil: inputSnoozedUntil,
            excludedAppFrontmost: inputExcludedAppFrontmost,
            onBattery: inputOnBattery,
            reduceTransparency: inputReduceTransparency,
            pauseOnBattery: settings.pauseOnBattery,
            reduceTransparencyResponse: settings.reduceTransparencyResponse,
            perDisplay: settings.perDisplay
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
