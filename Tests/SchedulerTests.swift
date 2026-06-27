import XCTest
@testable import Paperweight

class FakeClock: Clock {
    var now: Date
    var callCount = 0

    init(date: Date = Date()) {
        self.now = date
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

class SchedulerTests: XCTestCase {
    var fakeClock: FakeClock!

    override func setUp() {
        super.setUp()
        fakeClock = FakeClock()
    }

    // MARK: - Transition calculation tests

    func testIsScheduleActiveManualTimeWindow() {
        let solar = SolarCalculator()
        let scheduler = Scheduler(
            solar: solar,
            clock: fakeClock
        )

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: fakeClock.now)

        // Test 8:00 AM (before window)
        components.hour = 8
        components.minute = 0
        let beforeWindow = calendar.date(from: components)!
        XCTAssertFalse(
            scheduler.isScheduleActive(at: beforeWindow, schedule: .manual(fromHour: 9, fromMinute: 0, toHour: 17, toMinute: 0)),
            "Should be inactive before schedule window"
        )

        // Test 10:00 AM (within window)
        components.hour = 10
        let withinWindow = calendar.date(from: components)!
        XCTAssertTrue(
            scheduler.isScheduleActive(at: withinWindow, schedule: .manual(fromHour: 9, fromMinute: 0, toHour: 17, toMinute: 0)),
            "Should be active within schedule window"
        )

        // Test 6:00 PM (after window)
        components.hour = 18
        let afterWindow = calendar.date(from: components)!
        XCTAssertFalse(
            scheduler.isScheduleActive(at: afterWindow, schedule: .manual(fromHour: 9, fromMinute: 0, toHour: 17, toMinute: 0)),
            "Should be inactive after schedule window"
        )
    }

    func testIsScheduleActiveManualTimeWindowWithWraparound() {
        let solar = SolarCalculator()
        let scheduler = Scheduler(
            solar: solar,
            clock: fakeClock
        )

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: fakeClock.now)

        // Test 10:00 PM (within wrapped window 22:00-06:00)
        components.hour = 22
        let withinWrapped1 = calendar.date(from: components)!
        XCTAssertTrue(
            scheduler.isScheduleActive(at: withinWrapped1, schedule: .manual(fromHour: 22, fromMinute: 0, toHour: 6, toMinute: 0)),
            "Should be active within wrapped window at 10 PM"
        )

        // Test 2:00 AM (within wrapped window 22:00-06:00)
        components.hour = 2
        let withinWrapped2 = calendar.date(from: components)!
        XCTAssertTrue(
            scheduler.isScheduleActive(at: withinWrapped2, schedule: .manual(fromHour: 22, fromMinute: 0, toHour: 6, toMinute: 0)),
            "Should be active within wrapped window at 2 AM"
        )

        // Test 8:00 AM (outside wrapped window)
        components.hour = 8
        let outsideWrapped = calendar.date(from: components)!
        XCTAssertFalse(
            scheduler.isScheduleActive(at: outsideWrapped, schedule: .manual(fromHour: 22, fromMinute: 0, toHour: 6, toMinute: 0)),
            "Should be inactive outside wrapped window at 8 AM"
        )
    }

    func testIsScheduleActiveOffSchedule() {
        let solar = SolarCalculator()
        let scheduler = Scheduler(
            solar: solar,
            clock: fakeClock
        )

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: fakeClock.now)
        components.hour = 10
        let anyTime = calendar.date(from: components)!

        XCTAssertFalse(
            scheduler.isScheduleActive(at: anyTime, schedule: .off),
            "Should always be inactive when schedule is .off"
        )
    }

    // MARK: - Next-transition (timer arming) calculation

    /// At 10:00 the next manual-window transition is the 17:00 boundary today.
    func testNextTransitionPicksUpcomingBoundaryToday() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 10; components.minute = 0
        fakeClock.now = calendar.date(from: components)!
        let scheduler = Scheduler(clock: fakeClock)

        let next = scheduler.computeNextTransition(
            schedule: .manual(fromHour: 9, fromMinute: 0, toHour: 17, toMinute: 0)
        )

        components.hour = 17; components.minute = 0
        let expected = calendar.date(from: components)!
        XCTAssertEqual(next, expected)
    }

    /// After both of today's boundaries have passed, the next transition rolls to
    /// tomorrow's opening boundary.
    func testNextTransitionRollsToTomorrowAfterWindow() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 20; components.minute = 0
        fakeClock.now = calendar.date(from: components)!
        let scheduler = Scheduler(clock: fakeClock)

        let next = scheduler.computeNextTransition(
            schedule: .manual(fromHour: 9, fromMinute: 0, toHour: 17, toMinute: 0)
        )

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: fakeClock.now))!
        var expectedComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        expectedComponents.hour = 9; expectedComponents.minute = 0
        XCTAssertEqual(next, calendar.date(from: expectedComponents))
    }

    /// An `.off` schedule never arms a transition.
    func testNextTransitionIsNilWhenOff() {
        let scheduler = Scheduler(clock: fakeClock)
        XCTAssertNil(scheduler.computeNextTransition(schedule: .off))
    }
}

