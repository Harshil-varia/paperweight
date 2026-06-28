import AppKit

/// Monitors Reduce Transparency accessibility setting and reports changes.
protocol ReduceTransparencyMonitoring {
    func start()
    func stop()
}

class ReduceTransparencyMonitor: ReduceTransparencyMonitoring {
    weak var coordinator: AppCoordinator?
    private var observer: NSObjectProtocol?

    func start() {
        // Observe accessibility display options changes
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateReduceTransparency()
        }
        updateReduceTransparency()
    }

    func stop() {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    deinit {
        stop()
    }

    /// Update reduce transparency status from the real accessibility API.
    /// (The previous implementation read `AppleReduceTransparencyEnabled` from
    /// the app's standard UserDefaults, which never reflects the global setting —
    /// so the feature was effectively dead.)
    private func updateReduceTransparency() {
        guard let coordinator = coordinator else { return }
        coordinator.inputReduceTransparency =
            NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }
}
