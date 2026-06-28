import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    /// Posted by the menu-bar panel to open the Preferences window.
    static let paperweightShowPreferences = Notification.Name("PaperweightShowPreferences")
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = TextureEngine()
    let coordinator: AppCoordinator
    var overlayController: OverlayController?
    private var cancellables = Set<AnyCancellable>()

    /// Preferences is an AppKit-hosted window rather than a SwiftUI `Window`
    /// scene: `openWindow` from a `MenuBarExtra` in an `.accessory` app is
    /// unreliable about actually showing/focusing, which is why "Preferences did
    /// nothing". An NSWindow we own and order-front explicitly is dependable.
    private(set) var preferencesWindow: NSWindow?
    private var onboardingWindow: NSWindow?

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

        // Open Preferences when the menu-bar panel asks for it.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showPreferences),
            name: .paperweightShowPreferences,
            object: nil
        )

        // Re-assert overlay panels on wake: macOS can reset window levels and
        // displays may have changed while asleep. Timers also don't fire across
        // sleep, so this is where we recover the overlay after a lid-open.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // Initial reconcile
        overlayController?.reconcile(NSScreen.screens)

        // First-run onboarding (the previous SwiftUI Window scene was never
        // opened, so it never appeared).
        showOnboardingIfNeeded()
    }

    /// Show the one-time onboarding panel if the user hasn't seen it. Hosted as
    /// an AppKit window for the same reliability reason as Preferences.
    private func showOnboardingIfNeeded() {
        guard !coordinator.settings.hasSeenOnboarding else { return }

        NSApp.activate(ignoringOtherApps: true)
        let hosting = NSHostingController(
            rootView: OnboardingView(onDone: { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            }).environmentObject(coordinator)
        )
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.center()
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func screenParametersDidChange() {
        DispatchQueue.main.async {
            self.overlayController?.reconcile(NSScreen.screens)
        }
    }

    @objc private func systemDidWake() {
        DispatchQueue.main.async {
            self.overlayController?.reconcile(NSScreen.screens)
        }
    }

    /// Show (creating once, then reusing) the Preferences window and bring it to
    /// the front. `.accessory` apps must activate first or the window opens
    /// behind everything.
    @objc func showPreferences() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(
            rootView: PreferencesView().environmentObject(coordinator)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "Paperweight Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
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
