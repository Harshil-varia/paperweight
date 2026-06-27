# ADR-0004: No Render Loop — Discrete State Change Triggers Only

**Status**: Accepted  
**Date**: 2026-06-27  

## Context

Paperweight must maintain ~0% idle CPU and flat memory, regardless of display count/resolution. A continuous render loop (e.g., `CADisplayLink`, animation timer) burns CPU even when nothing has changed.

## Decision

The overlay is touched **only** when state changes. There is no continuous render loop. Redraws are triggered by:

1. **User input** (toggle, comfort slider, profile change) → `AppCoordinator` recomputes `resolved`
2. **Time-driven inputs** (schedule/snooze boundary) → one-shot `DispatchSourceTimer` fires
3. **Environmental inputs** (exclusion app, power, Reduce Transparency) → OS notification
4. **Display changes** (hot-plug, resolution, wake) → `didChangeScreenParametersNotification`

Each trigger runs `resolve()`, diffs the output, and only calls into `OverlayController` if state changed. The Combine `removeDuplicates()` sink reinforces this.

## Consequences

- Rendering latency is imperceptible (state changes are infrequent)
- CPU remains idle between state changes (no polling, no cadence)
- Animation is ruled out (would require a loop) — motion must be on-demand
- Extensive testing of reconciliation logic (state changes must be idempotent)
