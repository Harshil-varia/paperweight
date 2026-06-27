import Foundation

struct ResolvedOverlay: Equatable {
    var isVisible: Bool
    var profile: TextureProfile
    var effectiveOpacity: Float  // Clamped into the valid range [0.0, 1.0]
    /// Per-display visibility: maps display ID to whether it's enabled for that display
    var perDisplayVisibility: [DisplayID: Bool]

    init(
        isVisible: Bool,
        profile: TextureProfile,
        effectiveOpacity: Float,
        perDisplayVisibility: [DisplayID: Bool] = [:]
    ) {
        self.isVisible = isVisible
        self.profile = profile
        self.effectiveOpacity = max(0.0, min(1.0, effectiveOpacity))
        self.perDisplayVisibility = perDisplayVisibility
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

    // Phase 5: Ambient inputs
    /// Whether an excluded app is frontmost (forces hidden at highest precedence)
    var excludedAppFrontmost: Bool = false
    /// Whether the device is on battery
    var onBattery: Bool = false
    /// Whether Reduce Transparency accessibility setting is on
    var reduceTransparency: Bool = false
    /// Whether to pause overlay when on battery
    var pauseOnBattery: Bool = false
    /// How to respond to Reduce Transparency
    var reduceTransparencyResponse: ReduceTransparencyResponse = .stepDown
    /// Per-display visibility settings; maps display ID to whether it's enabled on that display
    var perDisplay: [DisplayID: DisplaySetting] = [:]

    init(
        isEnabled: Bool,
        selectedProfile: TextureProfile,
        comfort: Float,
        scheduleConfigured: Bool = false,
        scheduleActive: Bool,
        snoozedUntil: Date?,
        excludedAppFrontmost: Bool = false,
        onBattery: Bool = false,
        reduceTransparency: Bool = false,
        pauseOnBattery: Bool = false,
        reduceTransparencyResponse: ReduceTransparencyResponse = .stepDown,
        perDisplay: [DisplayID: DisplaySetting] = [:]
    ) {
        self.isEnabled = isEnabled
        self.selectedProfile = selectedProfile
        self.comfort = comfort
        self.scheduleConfigured = scheduleConfigured
        self.scheduleActive = scheduleActive
        self.snoozedUntil = snoozedUntil
        self.excludedAppFrontmost = excludedAppFrontmost
        self.onBattery = onBattery
        self.reduceTransparency = reduceTransparency
        self.pauseOnBattery = pauseOnBattery
        self.reduceTransparencyResponse = reduceTransparencyResponse
        self.perDisplay = perDisplay
    }
}

/// Pure resolver function: all precedence rules live here.
/// Precedence (highest to lowest):
/// 1. Snooze forces hidden while `snoozedUntil` is in the future.
/// 2. Excluded app frontmost forces hidden.
/// 3. Battery pause: if on battery and pauseOnBattery is true, hide.
/// 4. A configured schedule gates visibility to its active window.
/// 5. Master toggle (`isEnabled`).
/// 6. Reduce Transparency: if on, step comfort down or switch to flat matte.
///
/// Note: when no schedule is configured the overlay follows `isEnabled` alone —
/// the default (`.off`) must never hide the overlay (with no ambient condition, an enabled
/// overlay MUST be visible).
func resolve(_ inputs: OverlayInputs) -> ResolvedOverlay {
    var profile = inputs.selectedProfile
    var comfort = inputs.comfort

    // Snooze has highest precedence — forces hidden.
    if let snoozedUntil = inputs.snoozedUntil, Date() < snoozedUntil {
        var perDisplayVisibility: [DisplayID: Bool] = [:]
        for (displayID, _) in inputs.perDisplay {
            perDisplayVisibility[displayID] = false
        }
        return ResolvedOverlay(
            isVisible: false,
            profile: profile,
            effectiveOpacity: 0,
            perDisplayVisibility: perDisplayVisibility
        )
    }

    // Excluded app frontmost forces hidden.
    if inputs.excludedAppFrontmost {
        var perDisplayVisibility: [DisplayID: Bool] = [:]
        for (displayID, _) in inputs.perDisplay {
            perDisplayVisibility[displayID] = false
        }
        return ResolvedOverlay(
            isVisible: false,
            profile: profile,
            effectiveOpacity: 0,
            perDisplayVisibility: perDisplayVisibility
        )
    }

    // Battery pause: if on battery and pauseOnBattery is true, hide.
    if inputs.onBattery && inputs.pauseOnBattery {
        var perDisplayVisibility: [DisplayID: Bool] = [:]
        for (displayID, _) in inputs.perDisplay {
            perDisplayVisibility[displayID] = false
        }
        return ResolvedOverlay(
            isVisible: false,
            profile: profile,
            effectiveOpacity: 0,
            perDisplayVisibility: perDisplayVisibility
        )
    }

    // A schedule only gates when one is actually configured.
    let schedulePermits = !inputs.scheduleConfigured || inputs.scheduleActive
    let isVisible = inputs.isEnabled && schedulePermits

    // Reduce Transparency: step down comfort or switch to flat matte
    if inputs.reduceTransparency {
        switch inputs.reduceTransparencyResponse {
        case .stepDown:
            // Step down comfort by 50%
            comfort = comfort * 0.5
        case .flatMatte:
            // Switch to flat matte profile
            profile = .classicMatte
        }
    }

    let effectiveOpacity = profile.opacityRange.clamp(comfort)

    // Build per-display visibility map
    var perDisplayVisibility: [DisplayID: Bool] = [:]
    for (displayID, setting) in inputs.perDisplay {
        perDisplayVisibility[displayID] = isVisible && setting.isEnabled
    }

    return ResolvedOverlay(
        isVisible: isVisible,
        profile: profile,
        effectiveOpacity: effectiveOpacity,
        perDisplayVisibility: perDisplayVisibility
    )
}
