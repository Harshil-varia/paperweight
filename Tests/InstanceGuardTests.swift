import XCTest
@testable import Paperweight

/// The single-instance policy that stops a second Paperweight (e.g. a leftover
/// Debug build) from stacking a second menu-bar icon and overlay.
final class InstanceGuardTests: XCTestCase {
    func testYieldsWhenAnotherInstanceIsRunning() {
        XCTAssertTrue(InstanceGuard.shouldYield(toOthers: 1))
        XCTAssertTrue(InstanceGuard.shouldYield(toOthers: 3))
    }

    func testDoesNotYieldWhenAloneOrFirst() {
        XCTAssertFalse(InstanceGuard.shouldYield(toOthers: 0))
    }

    func testNegativeCountTreatedAsAlone() {
        // Defensive: a bogus negative count must not cause us to yield.
        XCTAssertFalse(InstanceGuard.shouldYield(toOthers: -1))
    }
}
