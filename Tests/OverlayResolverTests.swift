import XCTest
@testable import Paperweight

class OverlayResolverTests: XCTestCase {
    func testResolverVisibilityFromEnabled() {
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5
        )
        let resolved = resolve(inputs)
        XCTAssertTrue(resolved.isVisible)
    }

    func testResolverVisibilityWhenDisabled() {
        let inputs = OverlayInputs(
            isEnabled: false,
            selectedProfile: .eInkCalm,
            comfort: 0.5
        )
        let resolved = resolve(inputs)
        XCTAssertFalse(resolved.isVisible)
    }

    func testResolverClampsComfortIntoEInkCalmOpacityBand() {
        // E-Ink Calm has opacityRange (0.12, 0.25)
        // Comfort 0.0 should map to minOpacity (0.12)
        let minInputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.0
        )
        let minResolved = resolve(minInputs)
        XCTAssertAlmostEqual(minResolved.effectiveOpacity, 0.12, accuracy: 0.001)

        // Comfort 1.0 should map to maxOpacity (0.25)
        let maxInputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 1.0
        )
        let maxResolved = resolve(maxInputs)
        XCTAssertAlmostEqual(maxResolved.effectiveOpacity, 0.25, accuracy: 0.001)

        // Comfort 0.5 should map to mid-band
        let midInputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5
        )
        let midResolved = resolve(midInputs)
        XCTAssertAlmostEqual(midResolved.effectiveOpacity, 0.185, accuracy: 0.001)
    }

    func testResolverClampsComfortIntoClassicMatteOpacityBand() {
        // Classic Matte has opacityRange (0.15, 0.30)
        let minInputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .classicMatte,
            comfort: 0.0
        )
        let minResolved = resolve(minInputs)
        XCTAssertAlmostEqual(minResolved.effectiveOpacity, 0.15, accuracy: 0.001)

        let maxInputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .classicMatte,
            comfort: 1.0
        )
        let maxResolved = resolve(maxInputs)
        XCTAssertAlmostEqual(maxResolved.effectiveOpacity, 0.30, accuracy: 0.001)
    }

    func testResolverProfilePassthrough() {
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .classicMatte,
            comfort: 0.5
        )
        let resolved = resolve(inputs)
        XCTAssertEqual(resolved.profile.id, "classic-matte")
    }

    func testResolvedOverlayClampsOpacityToRange() {
        let overlay = ResolvedOverlay(
            isVisible: true,
            profile: .eInkCalm,
            effectiveOpacity: 1.5  // Out of range
        )
        XCTAssertEqual(overlay.effectiveOpacity, 1.0)

        let overlay2 = ResolvedOverlay(
            isVisible: true,
            profile: .eInkCalm,
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
