import XCTest
@testable import Paperweight

class OverlayResolverTests: XCTestCase {
    func testResolverVisibilityFromEnabled() {
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleActive: true,
            snoozedUntil: nil
        )
        let resolved = resolve(inputs)
        XCTAssertTrue(resolved.isVisible)
    }

    func testResolverVisibilityWhenDisabled() {
        let inputs = OverlayInputs(
            isEnabled: false,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleActive: true,
            snoozedUntil: nil
        )
        let resolved = resolve(inputs)
        XCTAssertFalse(resolved.isVisible)
    }

    func testResolverNoScheduleStaysVisibleWhenEnabled() {
        // The default (no schedule configured) must never hide the overlay,
        // regardless of the scheduleActive flag.
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleConfigured: false,
            scheduleActive: false,
            snoozedUntil: nil
        )
        XCTAssertTrue(resolve(inputs).isVisible)
    }

    func testResolverConfiguredScheduleGatesVisibilityWhenInactive() {
        // With a schedule configured and currently outside its window, hide.
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleConfigured: true,
            scheduleActive: false,
            snoozedUntil: nil
        )
        XCTAssertFalse(resolve(inputs).isVisible)
    }

    func testResolverConfiguredScheduleVisibleWhenActive() {
        // With a schedule configured and inside its window, show.
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleConfigured: true,
            scheduleActive: true,
            snoozedUntil: nil
        )
        XCTAssertTrue(resolve(inputs).isVisible)
    }

    func testResolverSnoozeForcesFalse() {
        // When snoozedUntil is in the future, visibility should be false
        let futureDate = Date(timeIntervalSinceNow: 600) // 10 minutes from now
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleActive: true,
            snoozedUntil: futureDate
        )
        let resolved = resolve(inputs)
        XCTAssertFalse(resolved.isVisible)
    }

    func testResolverSnoozeHighestPrecedence() {
        // Snooze takes precedence even if enabled and schedule active
        let futureDate = Date(timeIntervalSinceNow: 600)
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleActive: true,
            snoozedUntil: futureDate
        )
        let resolved = resolve(inputs)
        XCTAssertFalse(resolved.isVisible)
    }

    func testResolverSnoozeExpiredAllowsVisibility() {
        // When snoozedUntil is in the past, it should not force hidden
        let pastDate = Date(timeIntervalSinceNow: -600) // 10 minutes ago
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleActive: true,
            snoozedUntil: pastDate
        )
        let resolved = resolve(inputs)
        XCTAssertTrue(resolved.isVisible)
    }

    func testResolverClampsComfortIntoEInkCalmOpacityBand() {
        // E-Ink Calm has opacityRange (0.15, 0.25)
        // Comfort 0.0 should map to minOpacity (0.15)
        let minInputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.0,
            scheduleActive: true,
            snoozedUntil: nil
        )
        let minResolved = resolve(minInputs)
        XCTAssertAlmostEqual(minResolved.effectiveOpacity, 0.15, accuracy: 0.001)

        // Comfort 1.0 should map to maxOpacity (0.25)
        let maxInputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 1.0,
            scheduleActive: true,
            snoozedUntil: nil
        )
        let maxResolved = resolve(maxInputs)
        XCTAssertAlmostEqual(maxResolved.effectiveOpacity, 0.25, accuracy: 0.001)

        // Comfort 0.5 should map to mid-band
        let midInputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleActive: true,
            snoozedUntil: nil
        )
        let midResolved = resolve(midInputs)
        XCTAssertAlmostEqual(midResolved.effectiveOpacity, 0.20, accuracy: 0.001)
    }

    func testResolverClampsComfortIntoClassicMatteOpacityBand() {
        // Classic Matte has opacityRange (0.15, 0.21)
        let minInputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .classicMatte,
            comfort: 0.0,
            scheduleActive: true,
            snoozedUntil: nil
        )
        let minResolved = resolve(minInputs)
        XCTAssertAlmostEqual(minResolved.effectiveOpacity, 0.15, accuracy: 0.001)

        let maxInputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .classicMatte,
            comfort: 1.0,
            scheduleActive: true,
            snoozedUntil: nil
        )
        let maxResolved = resolve(maxInputs)
        XCTAssertAlmostEqual(maxResolved.effectiveOpacity, 0.21, accuracy: 0.001)
    }

    func testResolverProfilePassthrough() {
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .classicMatte,
            comfort: 0.5,
            scheduleActive: true,
            snoozedUntil: nil
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

    // MARK: - Phase 5: Precedence Tests

    func testExcludedAppFrontmostForcesFalse() {
        // Excluded app frontmost should force hidden
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleActive: true,
            snoozedUntil: nil,
            excludedAppFrontmost: true
        )
        let resolved = resolve(inputs)
        XCTAssertFalse(resolved.isVisible)
    }

    func testExcludedAppHigherPrecedenceThanSchedule() {
        // Excluded app should hide even with active schedule
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleConfigured: true,
            scheduleActive: true,
            snoozedUntil: nil,
            excludedAppFrontmost: true
        )
        let resolved = resolve(inputs)
        XCTAssertFalse(resolved.isVisible)
    }

    func testSnoozeHigherPrecedenceThanExcluded() {
        // Snooze is highest precedence, higher than excluded app
        let futureDate = Date(timeIntervalSinceNow: 600)
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleActive: true,
            snoozedUntil: futureDate,
            excludedAppFrontmost: true
        )
        let resolved = resolve(inputs)
        XCTAssertFalse(resolved.isVisible)
    }

    func testBatteryPauseForcesHidden() {
        // When on battery and pauseOnBattery is true, hide
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleActive: true,
            snoozedUntil: nil,
            excludedAppFrontmost: false,
            onBattery: true,
            reduceTransparency: false,
            pauseOnBattery: true
        )
        let resolved = resolve(inputs)
        XCTAssertFalse(resolved.isVisible)
    }

    func testBatteryPauseDisabledAllowsVisibility() {
        // When pauseOnBattery is false, battery status doesn't affect visibility
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleActive: true,
            snoozedUntil: nil,
            excludedAppFrontmost: false,
            onBattery: true,
            reduceTransparency: false,
            pauseOnBattery: false
        )
        let resolved = resolve(inputs)
        XCTAssertTrue(resolved.isVisible)
    }

    func testReduceTransparencyStepsDownComfort() {
        // When reduce transparency is on and response is stepDown, comfort should be halved
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 1.0,
            scheduleActive: true,
            snoozedUntil: nil,
            excludedAppFrontmost: false,
            onBattery: false,
            reduceTransparency: true,
            pauseOnBattery: false,
            reduceTransparencyResponse: .stepDown
        )
        let resolved = resolve(inputs)
        // E-Ink Calm opacityRange is (0.15, 0.25)
        // With comfort 1.0 * 0.5 (stepDown) = 0.5
        // 0.5 maps to: 0.15 + (0.5 * (0.25 - 0.15)) = 0.15 + 0.05 = 0.20
        XCTAssertAlmostEqual(resolved.effectiveOpacity, 0.20, accuracy: 0.001)
    }

    func testReduceTransparencyFlatMatte() {
        // When reduce transparency is on and response is flatMatte, profile should change
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleActive: true,
            snoozedUntil: nil,
            excludedAppFrontmost: false,
            onBattery: false,
            reduceTransparency: true,
            pauseOnBattery: false,
            reduceTransparencyResponse: .flatMatte
        )
        let resolved = resolve(inputs)
        XCTAssertEqual(resolved.profile.id, "classic-matte")
    }

    func testReduceTransparencyDisabledNoEffect() {
        // When reduce transparency is off, it shouldn't affect the profile or comfort
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleActive: true,
            snoozedUntil: nil,
            excludedAppFrontmost: false,
            onBattery: false,
            reduceTransparency: false,
            pauseOnBattery: false,
            reduceTransparencyResponse: .flatMatte
        )
        let resolved = resolve(inputs)
        XCTAssertEqual(resolved.profile.id, "eink-calm")
    }

    func testPerDisplayVisibilityMap() {
        // Test that per-display settings are properly reflected in the resolved overlay
        let perDisplay: [DisplayID: DisplaySetting] = [
            "0": DisplaySetting(isEnabled: true),
            "1": DisplaySetting(isEnabled: false),
            "2": DisplaySetting(isEnabled: true)
        ]
        let inputs = OverlayInputs(
            isEnabled: true,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleActive: true,
            snoozedUntil: nil,
            excludedAppFrontmost: false,
            onBattery: false,
            reduceTransparency: false,
            pauseOnBattery: false,
            reduceTransparencyResponse: .stepDown,
            perDisplay: perDisplay
        )
        let resolved = resolve(inputs)
        XCTAssertTrue(resolved.perDisplayVisibility["0"] ?? false)
        XCTAssertFalse(resolved.perDisplayVisibility["1"] ?? true)
        XCTAssertTrue(resolved.perDisplayVisibility["2"] ?? false)
    }

    func testPerDisplayVisibilityWhenOverlayHidden() {
        // When overlay is hidden globally, per-display should also be false
        let perDisplay: [DisplayID: DisplaySetting] = [
            "0": DisplaySetting(isEnabled: true),
            "1": DisplaySetting(isEnabled: true)
        ]
        let inputs = OverlayInputs(
            isEnabled: false,
            selectedProfile: .eInkCalm,
            comfort: 0.5,
            scheduleActive: true,
            snoozedUntil: nil,
            excludedAppFrontmost: false,
            onBattery: false,
            reduceTransparency: false,
            pauseOnBattery: false,
            reduceTransparencyResponse: .stepDown,
            perDisplay: perDisplay
        )
        let resolved = resolve(inputs)
        XCTAssertFalse(resolved.perDisplayVisibility["0"] ?? true)
        XCTAssertFalse(resolved.perDisplayVisibility["1"] ?? true)
    }
}

extension XCTestCase {
    func XCTAssertAlmostEqual(_ a: Float, _ b: Float, accuracy: Float) {
        XCTAssertTrue(abs(a - b) < accuracy, "\(a) is not almost equal to \(b) with accuracy \(accuracy)")
    }
}
