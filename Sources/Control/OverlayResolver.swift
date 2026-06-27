import Foundation

struct ResolvedOverlay: Equatable {
    var isVisible: Bool
    var profileID: String
    var effectiveOpacity: Float  // Clamped into the valid range [0.0, 1.0]

    init(isVisible: Bool, profileID: String, effectiveOpacity: Float) {
        self.isVisible = isVisible
        self.profileID = profileID
        self.effectiveOpacity = max(0.0, min(1.0, effectiveOpacity))
    }
}

struct OverlayInputs {
    var isEnabled: Bool
    var selectedProfileID: String
    var comfort: Float  // Normalized 0.0-1.0
}

/// Pure resolver function: all precedence rules live here
func resolve(_ inputs: OverlayInputs) -> ResolvedOverlay {
    let isVisible = inputs.isEnabled
    let profileID = inputs.selectedProfileID

    // Phase 1: comfort directly maps to opacity (0.15-0.30 band, clamped)
    // This will be replaced with profile-specific opacityRanges in Phase 2
    let minOpacity: Float = 0.15
    let maxOpacity: Float = 0.30
    let effectiveOpacity = minOpacity + (inputs.comfort * (maxOpacity - minOpacity))

    return ResolvedOverlay(
        isVisible: isVisible,
        profileID: profileID,
        effectiveOpacity: effectiveOpacity
    )
}
