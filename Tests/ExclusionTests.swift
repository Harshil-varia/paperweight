import XCTest
@testable import Paperweight

class ExclusionTests: XCTestCase {
    func testExactBundleIDMatch() {
        let exclusions = ["com.apple.Safari", "com.google.Chrome"]
        let bundleID = "com.google.Chrome"
        let isExcluded = exclusions.contains(bundleID)
        XCTAssertTrue(isExcluded)
    }

    func testBundleIDNoMatch() {
        let exclusions = ["com.apple.Safari", "com.google.Chrome"]
        let bundleID = "com.apple.Mail"
        let isExcluded = exclusions.contains(bundleID)
        XCTAssertFalse(isExcluded)
    }

    func testEmptyExclusionsList() {
        let exclusions: [String] = []
        let bundleID = "com.google.Chrome"
        let isExcluded = exclusions.contains(bundleID)
        XCTAssertFalse(isExcluded)
    }

    func testCaseSensitiveMatch() {
        let exclusions = ["com.apple.Safari"]
        let bundleID = "com.Apple.Safari"
        let isExcluded = exclusions.contains(bundleID)
        XCTAssertFalse(isExcluded, "Bundle ID matching should be case-sensitive")
    }

    func testPartialBundleIDNoMatch() {
        let exclusions = ["com.apple.Safari"]
        let bundleID = "com.apple"
        let isExcluded = exclusions.contains(bundleID)
        XCTAssertFalse(isExcluded)
    }

    func testMultipleExclusionsWithMatch() {
        let exclusions = [
            "com.apple.Finder",
            "com.apple.Safari",
            "com.google.Chrome",
            "org.mozilla.firefox"
        ]
        let bundleID = "org.mozilla.firefox"
        let isExcluded = exclusions.contains(bundleID)
        XCTAssertTrue(isExcluded)
    }

    func testEmptyStringBundleID() {
        let exclusions = ["com.apple.Safari"]
        let bundleID = ""
        let isExcluded = exclusions.contains(bundleID)
        XCTAssertFalse(isExcluded)
    }
}
