import XCTest
import AppKit
@testable import Paperweight

/// "Preferences does nothing" regression guard. Exercises the AppDelegate path
/// that the menu-bar "Preferences…" button triggers, asserting a real window is
/// created and then reused (not duplicated) on subsequent opens.
@MainActor
final class PreferencesWindowTests: XCTestCase {
    func testShowPreferencesCreatesAWindow() {
        let delegate = AppDelegate()
        XCTAssertNil(delegate.preferencesWindow, "no window before opening")

        delegate.showPreferences()

        let window = delegate.preferencesWindow
        XCTAssertNotNil(window, "Preferences must create a window")
        XCTAssertNotNil(window?.contentViewController, "window must host the Preferences view")
        XCTAssertFalse(window?.isReleasedWhenClosed ?? true, "window must survive being closed so it can reopen")
    }

    func testShowPreferencesReusesTheSameWindow() {
        let delegate = AppDelegate()
        delegate.showPreferences()
        let first = delegate.preferencesWindow
        delegate.showPreferences()
        let second = delegate.preferencesWindow
        XCTAssertTrue(first === second, "opening Preferences twice must reuse one window")
    }
}
