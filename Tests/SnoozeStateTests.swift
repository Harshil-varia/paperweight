import XCTest
@testable import Paperweight

/// The `isSnoozed` flag that drives the menu-bar Snooze/Resume control.
@MainActor
final class SnoozeStateTests: XCTestCase {
    func testIsSnoozedTrueWhenUntilInFuture() {
        let coordinator = AppCoordinator()
        coordinator.inputSnoozedUntil = Date().addingTimeInterval(10 * 60)
        XCTAssertTrue(coordinator.isSnoozed)
    }

    func testIsSnoozedFalseWhenUntilInPast() {
        let coordinator = AppCoordinator()
        coordinator.inputSnoozedUntil = Date().addingTimeInterval(-1)
        XCTAssertFalse(coordinator.isSnoozed)
    }

    func testIsSnoozedFalseWhenNil() {
        let coordinator = AppCoordinator()
        coordinator.inputSnoozedUntil = nil
        XCTAssertFalse(coordinator.isSnoozed)
    }
}
