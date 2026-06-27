import XCTest
@testable import Paperweight

class OverlayResolverTests: XCTestCase {
    func testResolverVisibilityFromEnabled() {
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfileID: "test",
            comfort: 0.5
        )
        let resolved = resolve(inputs)
        XCTAssertTrue(resolved.isVisible)
    }

    func testResolverVisibilityWhenDisabled() {
        let inputs = OverlayInputs(
            isEnabled: false,
            selectedProfileID: "test",
            comfort: 0.5
        )
        let resolved = resolve(inputs)
        XCTAssertFalse(resolved.isVisible)
    }

    func testResolverClampsComfortIntoOpacityBand() {
        // Comfort 0.0 should map to minOpacity (0.15)
        let minInputs = OverlayInputs(
            isEnabled: true,
            selectedProfileID: "test",
            comfort: 0.0
        )
        let minResolved = resolve(minInputs)
        XCTAssertAlmostEqual(minResolved.effectiveOpacity, 0.15, accuracy: 0.001)

        // Comfort 1.0 should map to maxOpacity (0.30)
        let maxInputs = OverlayInputs(
            isEnabled: true,
            selectedProfileID: "test",
            comfort: 1.0
        )
        let maxResolved = resolve(maxInputs)
        XCTAssertAlmostEqual(maxResolved.effectiveOpacity, 0.30, accuracy: 0.001)

        // Comfort 0.5 should map to mid-band
        let midInputs = OverlayInputs(
            isEnabled: true,
            selectedProfileID: "test",
            comfort: 0.5
        )
        let midResolved = resolve(midInputs)
        XCTAssertAlmostEqual(midResolved.effectiveOpacity, 0.225, accuracy: 0.001)
    }

    func testResolverProfileIDPassthrough() {
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfileID: "custom-profile",
            comfort: 0.5
        )
        let resolved = resolve(inputs)
        XCTAssertEqual(resolved.profileID, "custom-profile")
    }

    func testResolvedOverlayClampsOpacityToRange() {
        let overlay = ResolvedOverlay(
            isVisible: true,
            profileID: "test",
            effectiveOpacity: 1.5  // Out of range
        )
        XCTAssertEqual(overlay.effectiveOpacity, 1.0)

        let overlay2 = ResolvedOverlay(
            isVisible: true,
            profileID: "test",
            effectiveOpacity: -0.5  // Out of range
        )
        XCTAssertEqual(overlay2.effectiveOpacity, 0.0)
    }
}

extension XCTestCase {
    func XCTAssertAlmostEqual(_ a: Float, _ b: Float, accuracy: Float) {
        XCTAssertTrue(abs(a - b) < accuracy, "\(a) is not almost equal to \(b) with accuracy \(accuracy)")
    }
}
