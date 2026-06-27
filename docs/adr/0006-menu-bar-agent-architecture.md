# ADR-0006: Menu Bar Agent Architecture

**Status**: Accepted  
**Date**: 2026-06-27  

## Context

Paperweight is a utility (not a full-featured app) that must:
- Never appear in the Dock
- Never take focus or interfere with user input
- Be launchable from menu bar
- Persist across Spaces, hot-plug, and full-screen apps

## Decision

Architecture is a SwiftUI `@main App` with:
- `LSUIElement: YES` (Dock-less) in Info.plist
- `setActivationPolicy(.accessory)` in AppDelegate (no Dock icon)
- `MenuBarExtra(.window)` scene (menu-bar popover)
- `Settings` window scene (Preferences)
- `@NSApplicationDelegateAdaptor` to own AppKit resources (overlay, coordinator, input monitors)

The AppDelegate is necessary because:
- `scenePhase` is unreliable on macOS for lifecycle
- AppKit resources (panels, timers) must have a clear owner
- Input notifications are not SwiftUI-native

## Consequences

- SwiftUI handles UI logic; AppDelegate handles system integration
- No Dock icon means no app-switcher visibility
- MenuBarExtra popover is the only persistent UI entry point
- Settings window is modal (opened from menu or not shown at all)
