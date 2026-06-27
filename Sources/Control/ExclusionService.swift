import AppKit

/// Watches for app activation and reports whether an excluded app is frontmost.
protocol ExclusionMonitoring {
    func start()
    func stop()
}

class ExclusionService: ExclusionMonitoring {
    weak var coordinator: AppCoordinator?
    private var observer: NSObjectProtocol?

    func start() {
        // Observe NSWorkspace notifications on NSWorkspace.shared.notificationCenter
        // (NOT NotificationCenter.default)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFrontmostApp()
        }
    }

    func stop() {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    deinit {
        stop()
    }

    /// Check if the currently frontmost app is in the exclusion list
    private func checkFrontmostApp() {
        guard let coordinator = coordinator else { return }
        let exclusions = coordinator.settings.exclusions
        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        let isFrontmostExcluded = exclusions.contains(frontmostBundleID)
        coordinator.inputExcludedAppFrontmost = isFrontmostExcluded
    }
}
