import AppKit
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()
    var overlayController: OverlayController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Create and own the overlay controller
        overlayController = OverlayController()

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
