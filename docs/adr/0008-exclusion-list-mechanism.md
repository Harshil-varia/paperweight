# ADR 0008: Exclusion List Mechanism

**Date**: 2026-06-27  
**Status**: Accepted  
**Context**: Auto-hide overlay when specific applications are frontmost  
**Decision**: Observe app activation via `NSWorkspace.shared.notificationCenter`, match bundle IDs, and force-hide in resolver precedence  

## Problem

The app needs to automatically hide the overlay when certain applications (e.g., video players, presentations, eye-strain-sensitive workflows) are active, then restore it when those apps lose focus. The design space includes two approaches:

1. **Global NotificationCenter** — use `NSNotificationCenter.defaultCenter()` and listen for workspace activation globally, hooking into system-wide event stream.
2. **NSWorkspace's own notification center** — use `NSWorkspace.shared.notificationCenter` (the workspace-specific center), which is more efficient and isolation-friendly.

## Decision

Implement app-exclusion monitoring via `NSWorkspace.shared.notificationCenter`, matching bundle IDs in a simple list, and forcing the overlay hidden via the resolver precedence function.

### Rationale

**Efficient and local**:
- `NSWorkspace.shared.notificationCenter` is the workspace's own notification center, not the global `defaultCenter()`.
- Reduces noise in the global notification stream; only workspace events (app activation/deactivation, screen sleep, etc.) are posted here.
- Simplifies debugging: exclusion notifications don't pollute other parts of the app's observer chain.

**Direct bundle ID matching**:
- Bundle IDs are the stable, standard identifier for applications on macOS (`com.apple.Safari`, `com.google.Chrome`, etc.).
- Users can find bundle IDs via `mdls -name kMDItemCFBundleIdentifier /Applications/AppName.app` or via the app's own Info.plist.
- Case-insensitive substring matching is avoided; exact bundle ID match is cleaner and less error-prone.

**Highest precedence in resolve()**:
- Excluded app frontmost ⇒ `isVisible = false` — no other input (snooze, schedule, battery) overrides.
- Avoids visual flicker: one app activation = one state transition.
- If user re-activates an excluded app after a snooze, snooze is honored *except* for the exclusion (i.e., overlay still hidden). This is the right behavior: exclusion is the strongest intent.

**Simple seeded defaults**:
- Common exclusions (Zoom, Keynote, Finder) can be pre-populated in the default settings.
- Users can add/remove via the Exclusions tab without restarting the app; changes persist immediately.

### Trade-offs

**Bundle ID vs. app name**:
- *Pro*: Bundle ID is stable, unambiguous, and survives app renames.
- *Con*: Users must know (or look up) the bundle ID; slightly higher friction than "type app name."
- *Mitigation*: Document in Help; optionally add an app picker in Preferences later (would read running apps and their bundle IDs), but for Phase 5 MVP, text input is sufficient.

**No process-level granularity**:
- Exclusion is at the application level (all processes with that bundle ID), not per-window or per-process.
- *Acceptable*: Standard macOS apps are single-process; exclusion applies to the entire app, which is the expected behavior.

**Performance on app-dense systems**:
- Each app activation fires a notification; coordinator updates `inputExcludedAppFrontmost`.
- With dozens of running apps, this is negligible; notification delivery is O(1) per activation.
- *If* this becomes a bottleneck (unlikely), can add a debounce timer, but that introduces race conditions; not justified now.

## Implementation

- **`ExclusionService.swift`**: Observes `NSWorkspace.shared.notificationCenter` for `NSWorkspace.didActivateApplicationNotification`.
  - On notification, queries `NSRunningApplication.runningApplications(withBundleIdentifier:)` for the active app.
  - Calls `matches(bundleID:in: settings.exclusions)` — case-sensitive exact match.
  - Posts `inputExcludedAppFrontmost = true/false` to coordinator.
- **`OverlayResolver.swift`**: Precedence function checks `excludedAppFrontmost` *first* (before snooze, schedule, battery):
  ```swift
  if inputs.excludedAppFrontmost {
      return ResolvedOverlay(isVisible: false, ...)  // Forced hidden
  }
  // Other precedence rules (snooze, battery, schedule, RT)...
  ```
- **Settings defaults**: seed with a short list (Zoom, Keynote, Finder) if desired; user can modify in Preferences.
- **UI**: Exclusions tab (Phase 5) provides add/remove interface; shows current exclusion list and allows text input of bundle IDs.

## References

- **NSWorkspace.shared.notificationCenter**: https://developer.apple.com/documentation/appkit/nsworkspace/1534950-notificationcenter
- **didActivateApplicationNotification**: https://developer.apple.com/documentation/appkit/nsworkspace/1533959-didactivateapplicationnotificatio
- **NSRunningApplication**: https://developer.apple.com/documentation/appkit/nsrunningapplication

## Approval

✅ **Accepted**: Workspace-specific notification center is cleaner, bundle ID matching is standard macOS practice, and resolver precedence ensures clean semantics with no visual flicker.
