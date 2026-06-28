import AppKit
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = TextureEngine()
    let coordinator: AppCoordinator
    var overlayController: OverlayController?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        self.coordinator = AppCoordinator(engine: engine)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance guard. Paperweight is a menu-bar agent: a second copy
        // (for example a leftover Debug build running alongside a Release build)
        // would add a second menu-bar icon and stack a second overlay on every
        // display — which looks like "two identical apps". If another instance
        // with our bundle identifier is already running, surrender immediately so
        // the user only ever sees one. Never fires under the XCTest host.
        if !AppDelegate.isRunningTests, hasAnotherRunningInstance() {
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        // Register bundled JetBrains Mono faces before any UI renders.
        FontRegistrar.registerBundledFonts()

        // Create and own the overlay controller with engine access
        overlayController = OverlayController(engine: engine)

        // Bind coordinator's resolved overlay to the overlay controller
        coordinator.$resolved
            .removeDuplicates()
            .sink { [weak self] resolved in
                self?.overlayController?.apply(resolved)
            }
            .store(in: &cancellables)

        // Observe screen changes and reconcile panels
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Initial reconcile
        overlayController?.reconcile(NSScreen.screens)
    }

    @objc private func screenParametersDidChange() {
        DispatchQueue.main.async {
            self.overlayController?.reconcile(NSScreen.screens)
        }
    }

    /// True when running inside the XCTest host, where the instance guard and
    /// overlay setup must be skipped.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Whether another process with our bundle identifier is already running.
    /// Debug and Release builds share `com.humanlayer.paperweight`, so this also
    /// catches the common "two builds at once" case during development.
    private func hasAnotherRunningInstance() -> Bool {
        let myID = Bundle.main.bundleIdentifier ?? "com.humanlayer.paperweight"
        let others = NSRunningApplication
            .runningApplications(withBundleIdentifier: myID)
            .filter { $0 != NSRunningApplication.current }
        return InstanceGuard.shouldYield(toOthers: others.count)
    }
}

/// Pure single-instance decision, split out so the policy is unit-testable
/// without spawning real processes.
enum InstanceGuard {
    /// Yield (terminate self) when at least one other instance is already running.
    static func shouldYield(toOthers otherInstanceCount: Int) -> Bool {
        otherInstanceCount > 0
    }
}
