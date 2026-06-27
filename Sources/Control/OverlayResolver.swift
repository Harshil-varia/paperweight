import Foundation

struct ResolvedOverlay: Equatable {
    var isVisible: Bool
    var profile: TextureProfile
    var effectiveOpacity: Float  // Clamped into the valid range [0.0, 1.0]

    init(isVisible: Bool, profile: TextureProfile, effectiveOpacity: Float) {
        self.isVisible = isVisible
        self.profile = profile
        self.effectiveOpacity = max(0.0, min(1.0, effectiveOpacity))
    }
}

struct OverlayInputs {
    var isEnabled: Bool
    var selectedProfile: TextureProfile
    var comfort: Float  // Normalized 0.0-1.0
}

/// Pure resolver function: all precedence rules live here
func resolve(_ inputs: OverlayInputs) -> ResolvedOverlay {
    let isVisible = inputs.isEnabled
    let profile = inputs.selectedProfile

    // Phase 2: clamp comfort into the profile's opacityRange
    let effectiveOpacity = profile.opacityRange.clamp(inputs.comfort)

    return ResolvedOverlay(
        isVisible: isVisible,
        profile: profile,
        effectiveOpacity: effectiveOpacity
    )
}
