import XCTest
import CoreImage
@testable import Paperweight

/// The overlay's character comes from `CALayer.compositingFilter`, which is set
/// from `BlendMode.compositingFilterName`. A typo there fails silently — the
/// layer just composites normally and the blend is lost — so we pin the mapping
/// and verify each name corresponds to a real Core Image blend filter.
final class BlendModeMappingTests: XCTestCase {
    /// Short compositing-filter name → the canonical CIFilter name it maps to.
    private let expected: [BlendMode: (short: String, ci: String)] = [
        .softLight: ("softLightBlendMode", "CISoftLightBlendMode"),
        .multiply:  ("multiplyBlendMode", "CIMultiplyBlendMode"),
        .screen:    ("screenBlendMode", "CIScreenBlendMode"),
        .overlay:   ("overlayBlendMode", "CIOverlayBlendMode")
    ]

    func testEachBlendModeMapsToExpectedName() {
        for (mode, names) in expected {
            XCTAssertEqual(mode.compositingFilterName, names.short,
                           "\(mode) mapped to an unexpected compositing filter name")
        }
    }

    func testEveryBlendModeBacksARealCoreImageFilter() {
        for (mode, names) in expected {
            XCTAssertNotNil(CIFilter(name: names.ci),
                            "\(mode) → \(names.ci) is not a real Core Image filter")
        }
    }

    func testBlendModeNamesAreUnique() {
        let names = BlendMode.allCasesForTest.map { $0.compositingFilterName }
        XCTAssertEqual(Set(names).count, names.count, "compositing filter names must be distinct")
    }

    func testEveryPresetUsesAMappedBlendMode() {
        for profile in TextureProfile.flatPresets {
            XCTAssertNotNil(expected[profile.blendMode],
                            "preset \(profile.name) uses an unmapped blend mode")
        }
    }
}

// BlendMode is a small closed enum; enumerate the cases for the uniqueness check
// without forcing CaseIterable onto the production type.
private extension BlendMode {
    static var allCasesForTest: [BlendMode] { [.softLight, .multiply, .screen, .overlay] }
}
