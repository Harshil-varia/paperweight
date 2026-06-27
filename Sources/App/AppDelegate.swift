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
}
