import Foundation

/// A one-shot snooze timer that silences the overlay for a specified duration.
class SnoozeTimer {
    private weak var coordinator: AppCoordinator?
    private let clock: Clock
    private let timerFactory: DispatchTimerFactory
    private let queue = DispatchQueue(label: "com.humanlayer.paperweight.snooze")

    private var timer: DispatchSourceTimer?

    init(
        clock: Clock = SystemClock(),
        timerFactory: DispatchTimerFactory = SystemDispatchTimerFactory()
    ) {
        self.coordinator = nil
        self.clock = clock
        self.timerFactory = timerFactory
    }

    /// Set the coordinator after initialization (to avoid circular dependency issues)
    func setCoordinator(_ coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    /// Start a snooze for the specified number of minutes.
    /// After the duration expires, calls `coordinator.update(snoozedUntil: nil)` to resume.
    func start(minutes: Int) {
        queue.async { [weak self] in
            self?.cancelInternal()

            let now = self?.clock.now ?? Date()
            let snoozedUntil = Calendar.current.date(byAdding: .minute, value: minutes, to: now)

            self?.coordinator?.update(snoozedUntil: snoozedUntil)

            let newTimer = self?.timerFactory.makeTimer()
            newTimer?.schedule(deadline: .now() + TimeInterval(minutes * 60))
            newTimer?.setEventHandler { [weak self] in
                self?.queue.async { [weak self] in
                    self?.onTimerFired()
                }
            }

            newTimer?.resume()
            self?.timer = newTimer
        }
    }

    /// Cancel an active snooze and resume normal operation.
    func cancel() {
        queue.async { [weak self] in
            self?.cancelInternal()
            self?.coordinator?.update(snoozedUntil: nil)
        }
    }

    // MARK: - Private

    private func cancelInternal() {
        timer?.cancel()
        timer = nil
    }

    private func onTimerFired() {
        cancelInternal()
        coordinator?.update(snoozedUntil: nil)
    }
}

// MARK: - AppCoordinator extension

extension AppCoordinator {
    /// Update the snooze state. The snooze timer fires on a background queue, so
    /// hop to main before touching @Published state (the didSet on
    /// `inputSnoozedUntil` runs recompute()).
    func update(snoozedUntil: Date?) {
        AppCoordinator.runOnMain { [weak self] in
            self?.inputSnoozedUntil = snoozedUntil
        }
    }
}
