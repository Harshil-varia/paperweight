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
    /// Whether a schedule is configured at all (schedule != .off). When false,
    /// the schedule never gates visibility — `scheduleActive` is then irrelevant.
    var scheduleConfigured: Bool
    /// Whether we are currently inside the schedule's active window. Only
    /// meaningful when `scheduleConfigured` is true.
    var scheduleActive: Bool
    var snoozedUntil: Date?

    init(
        isEnabled: Bool,
        selectedProfile: TextureProfile,
        comfort: Float,
        scheduleConfigured: Bool = false,
        scheduleActive: Bool,
        snoozedUntil: Date?
    ) {
        self.isEnabled = isEnabled
        self.selectedProfile = selectedProfile
        self.comfort = comfort
        self.scheduleConfigured = scheduleConfigured
        self.scheduleActive = scheduleActive
        self.snoozedUntil = snoozedUntil
    }
}

/// Pure resolver function: all precedence rules live here.
/// Precedence (highest to lowest):
/// 1. Snooze forces hidden while `snoozedUntil` is in the future.
/// 2. A configured schedule gates visibility to its active window.
/// 3. Master toggle (`isEnabled`).
///
/// Note: when no schedule is configured the overlay follows `isEnabled` alone —
/// the default (`.off`) must never hide the overlay.
func resolve(_ inputs: OverlayInputs) -> ResolvedOverlay {
    let profile = inputs.selectedProfile
    let effectiveOpacity = profile.opacityRange.clamp(inputs.comfort)

    // Snooze has highest precedence — forces hidden.
    if let snoozedUntil = inputs.snoozedUntil, Date() < snoozedUntil {
        return ResolvedOverlay(isVisible: false, profile: profile, effectiveOpacity: effectiveOpacity)
    }

    // A schedule only gates when one is actually configured.
    let schedulePermits = !inputs.scheduleConfigured || inputs.scheduleActive
    let isVisible = inputs.isEnabled && schedulePermits

    return ResolvedOverlay(isVisible: isVisible, profile: profile, effectiveOpacity: effectiveOpacity)
}
