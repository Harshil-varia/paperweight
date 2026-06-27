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

    /// Update reduce transparency status
    private func updateReduceTransparency() {
        guard let coordinator = coordinator else { return }
        // Check the system's reduce transparency setting
        // This is a proxy for the Accessibility > Display > Increase Transparency setting
        let defaults = UserDefaults.standard
        let reduceTransparency = defaults.bool(forKey: "AppleReduceTransparencyEnabled")
        coordinator.inputReduceTransparency = reduceTransparency
    }
}
