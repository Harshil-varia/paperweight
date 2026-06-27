# ADR-0001: Window Level and Collection Behaviour

**Status**: Accepted  
**Date**: 2026-06-27  

## Context

The overlay must remain visible on every connected display, survive Spaces, full-screen apps, and hot-plug/resolution changes. macOS provides several window levels and collection behaviors to influence window stacking and visibility.

## Decision

The overlay uses:
- **Window Level**: `.screenSaver` — above everything except full-screen games (acceptable limit per ticket)
- **Collection Behavior**: `[.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`

This combination ensures:
- `.canJoinAllSpaces`: visible on every Space (no Space-switch hiding)
- `.stationary`: doesn't move with parallax across Spaces
- `.fullScreenAuxiliary`: shows alongside full-screen apps
- `.ignoresCycle`: out of Cmd-Tab and Window menu (non-activating)

The `.screenSaver` level is chosen over alternatives:
- `.statusBar` (menu bar level): too low; hidden by full-screen apps
- `.floating` or `.popUpMenu`: too high; interferes with system dialogs

## Consequences

- Native full-screen games may undercut the overlay (known acceptable limit)
- Re-asserting level + frame on screen-parameter changes prevents regressions
- Memory safety requires panel lifecycle tied to screen reconciliation
