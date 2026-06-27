import Foundation

/// Abstraction over system time for testability
protocol Clock {
    var now: Date { get }
}

struct SystemClock: Clock {
    var now: Date {
        Date()
    }
}

/// Factory for creating dispatch timers, allows injection of synchronous timers in tests
protocol DispatchTimerFactory {
    func makeTimer() -> DispatchSourceTimer
}

struct SystemDispatchTimerFactory: DispatchTimerFactory {
    func makeTimer() -> DispatchSourceTimer {
        DispatchSource.makeTimerSource()
    }
}

/// Schedules overlay state transitions based on a ScheduleConfig.
///
/// The scheduler computes the next transition instant (when the overlay should turn on/off
/// based on the schedule) and arms a single one-shot `DispatchSourceTimer`. When the timer
/// fires, it calls `update(scheduleActive:)` on the coordinator and re-arms for the next
/// transition. Between transitions, the process does no work.
final class Scheduler: @unchecked Sendable {
    private weak var coordinator: AppCoordinator?
    private let solar: SolarCalculating
    private let clock: Clock
    private let timerFactory: DispatchTimerFactory
    private let queue = DispatchQueue(label: "com.humanlayer.paperweight.scheduler")

    private var timer: DispatchSourceTimer?
    private var currentSchedule: ScheduleConfig?

    init(
        solar: SolarCalculating = SolarCalculator(),
        clock: Clock = SystemClock(),
        timerFactory: DispatchTimerFactory = SystemDispatchTimerFactory()
    ) {
        self.coordinator = nil
        self.solar = solar
        self.clock = clock
        self.timerFactory = timerFactory
    }

    /// Set the coordinator after initialization (to avoid circular dependency issues)
    func setCoordinator(_ coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    /// Start the scheduler with the given schedule config.
    /// Computes the next transition and arms a timer for it.
    func start(with schedule: ScheduleConfig) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.currentSchedule = schedule
            // Seed the current within-window state immediately so the overlay
            // reflects the schedule right away rather than waiting for the next
            // boundary to fire. For `.off` this reports inactive, which the
            // resolver ignores because no schedule is configured.
            self.coordinator?.update(
                scheduleActive: self.isScheduleActive(at: self.clock.now, schedule: schedule)
            )
            self.armNext()
        }
    }

    /// Stop the scheduler and invalidate the current timer.
    func stop() {
        queue.async { [weak self] in
            self?.timer?.cancel()
            self?.timer = nil
            self?.currentSchedule = nil
        }
    }

    // MARK: - Private

    private func armNext() {
        guard let schedule = currentSchedule else {
            return
        }

        // Cancel any existing timer
        if let existingTimer = timer {
            existingTimer.cancel()
        }

        // Compute next transition time
        guard let nextTransition = computeNextTransition(schedule: schedule) else {
            // No next transition (e.g., polar region with no event)
            timer = nil
            coordinator?.update(scheduleActive: false)
            return
        }

        let now = clock.now
        let timeInterval = nextTransition.timeIntervalSince(now)

        // If the transition is in the past, recompute (shouldn't happen, but safety)
        if timeInterval <= 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                self.queue.async { [weak self] in
                    self?.armNext()
                }
            }
            return
        }

        let newTimer = timerFactory.makeTimer()
        newTimer.schedule(deadline: .now() + timeInterval)
        let weakSelf = self as Scheduler?
        newTimer.setEventHandler { [weak weakSelf] in
            weakSelf?.queue.async { [weak weakSelf] in
                weakSelf?.onTimerFired()
            }
        }

        newTimer.resume()
        timer = newTimer
    }

    private func onTimerFired() {
        guard let schedule = currentSchedule else {
            return
        }

        // Determine if we're entering or exiting the active period
        let now = clock.now
        let isNowActive = isScheduleActive(at: now, schedule: schedule)

        coordinator?.update(scheduleActive: isNowActive)

        // Re-arm for the next transition
        armNext()
    }

    /// Computes the single next transition instant for a schedule from `clock.now`.
    /// Exposed (internal) so tests can verify timer arming deterministically.
    func computeNextTransition(schedule: ScheduleConfig) -> Date? {
        let now = clock.now
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        switch schedule {
        case .off:
            return nil

        case let .manual(fromHour, fromMinute, toHour, toMinute):
            var components = calendar.dateComponents([.year, .month, .day], from: today)

            // Try today's from time
            components.hour = fromHour
            components.minute = fromMinute
            if let fromTime = calendar.date(from: components), fromTime > now {
                return fromTime
            }

            // Try today's to time
            components.hour = toHour
            components.minute = toMinute
            if let toTime = calendar.date(from: components), toTime > now {
                return toTime
            }

            // Move to tomorrow and try from time
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
                var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                tomorrowComponents.hour = fromHour
                tomorrowComponents.minute = fromMinute
                return calendar.date(from: tomorrowComponents)
            }

            return nil

        case let .solar(latitude, longitude):
            // Get the user's timezone
            guard let timeZone = TimeZone.current as TimeZone? else {
                return nil
            }

            // Compute sunrise and sunset for today
            let sunrise = solar.sunrise(lat: latitude, long: longitude, date: today, in: timeZone)
            let sunset = solar.sunset(lat: latitude, long: longitude, date: today, in: timeZone)

            // Collect next potential transitions
            var potentialTransitions: [Date] = []

            if case let .event(sunriseTime) = sunrise, sunriseTime > now {
                potentialTransitions.append(sunriseTime)
            }
            if case let .event(sunsetTime) = sunset, sunsetTime > now {
                potentialTransitions.append(sunsetTime)
            }

            // If no transitions today, try tomorrow
            if potentialTransitions.isEmpty {
                if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
                    let tomorrowSunrise = solar.sunrise(lat: latitude, long: longitude, date: tomorrow, in: timeZone)
                    let tomorrowSunset = solar.sunset(lat: latitude, long: longitude, date: tomorrow, in: timeZone)

                    if case let .event(sunriseTime) = tomorrowSunrise {
                        potentialTransitions.append(sunriseTime)
                    }
                    if case let .event(sunsetTime) = tomorrowSunset {
                        potentialTransitions.append(sunsetTime)
                    }
                }
            }

            return potentialTransitions.min()
        }
    }

    func isScheduleActive(at date: Date, schedule: ScheduleConfig) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        switch schedule {
        case .off:
            return false

        case let .manual(fromHour, fromMinute, toHour, toMinute):
            let timeInMinutes = hour * 60 + minute
            let fromInMinutes = fromHour * 60 + fromMinute
            let toInMinutes = toHour * 60 + toMinute

            if fromInMinutes <= toInMinutes {
                // No wraparound (e.g., 9:00 to 18:00)
                return timeInMinutes >= fromInMinutes && timeInMinutes < toInMinutes
            } else {
                // Wraparound (e.g., 22:00 to 6:00)
                return timeInMinutes >= fromInMinutes || timeInMinutes < toInMinutes
            }

        case let .solar(latitude, longitude):
            guard let timeZone = TimeZone.current as TimeZone? else {
                return false
            }

            let calendar = Calendar.current
            let dayStart = calendar.startOfDay(for: date)

            let sunrise = solar.sunrise(lat: latitude, long: longitude, date: dayStart, in: timeZone)
            let sunset = solar.sunset(lat: latitude, long: longitude, date: dayStart, in: timeZone)

            // If either is a polar no-event, treat as inactive
            guard case let .event(sunriseTime) = sunrise, case let .event(sunsetTime) = sunset else {
                return false
            }

            // Overlay is active between sunrise and sunset
            return date >= sunriseTime && date < sunsetTime
        }
    }
}

// MARK: - AppCoordinator extension

extension AppCoordinator {
    /// Update the scheduler active state from the scheduler
    func update(scheduleActive: Bool) {
        inputScheduleActive = scheduleActive
        recompute()
    }
}
