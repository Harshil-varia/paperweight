# ADR 0007: Solar Calculation vs. CoreLocation

**Date**: 2026-06-27  
**Status**: Accepted  
**Context**: Schedule overlay on/off by sunrise/sunset  
**Decision**: Pure-Foundation NOAA/Meeus calculation from manual lat/long, no CoreLocation  

## Problem

The app needs to support a solar schedule mode that turns the overlay on at sunrise and off at sunset, computed for a user-specified latitude/longitude. The design space has two approaches:

1. **CoreLocation API** — request user's current location at runtime, fetch geo-coordinates automatically, query solar times via private API or third-party service.
2. **Pure-Foundation calculation** — user enters lat/long in Preferences once, compute sunrise/sunset purely in Foundation using NOAA/Meeus algorithm, no location permission needed.

## Decision

Implement pure-Foundation sunrise/sunset calculation from manual lat/long input, with no CoreLocation dependency.

### Rationale

**No location permission**, no permission prompt:
- CoreLocation requires `NSLocationWhenInUseUsageDescription` in Info.plist and a runtime permission dialog ("Paperweight would like access to your location…"). Even if the user grants permission, it adds friction and concerns around privacy.
- Manual lat/long eliminates the permission, supporting the privacy-first design principle stated in the ticket.

**Zero runtime third-party dependency**:
- Pure Foundation (`Date`, `Calendar`, `TimeZone`) + integer math ⇒ no external crate or HTTP fetch.
- Makes testing and shipping easier (no API key management, no rate-limit concerns, works offline).

**Deterministic and fast**:
- NOAA/Meeus algorithm runs in <1ms, same result every time given same input.
- No network round-trip, no asynchronous complexity.

**Known reference implementation exists**:
- `ceeK/Solar` (MIT license, Swift, Foundation-only) and `SunCalc` (BSD-2, JS) are both permissively licensed, well-validated implementations.
- Porting the algorithm clean-room from NOAA docs is straightforward: <200 lines of coordinate geometry and trigonometry.

**Polar edge case handled cleanly**:
- Polar regions (lat > ±66.5°) experience 24-hour daylight or darkness on some dates.
- Returning a `.noEvent` sentinel (rather than crashing or returning NaN) lets the scheduler gracefully handle "the sun doesn't rise today" scenarios.

### Trade-offs

**Manual lat/long vs. automatic location**:
- *Pro*: No permission, no network, user has control, works in any timezone.
- *Con*: User must know their lat/long (easy to look up, e.g., via Maps) or navigate Preferences to enter it.
- *Mitigation*: Store in Preferences; default to equator (0°, 0°) or let first-run onboarding guide it; document the lookup in Help.

**Algorithm accuracy**:
- NOAA/Meeus guarantees ±1 minute within ±72° latitude; degrades near poles but .noEvent sentinel catches worst cases.
- For the app's use case (overlay on/off), ±1 min is more than sufficient; users won't notice an extra 30 seconds of texture at sunrise.
- *If* golden-value tests reveal drift, can upgrade to NREL SPA (±0.0003°) but it's over-spec for this use case.

**Optional upgrade path**:
- If future UX research shows users want automatic location, can layer CoreLocation on top:
  - Keep the pure algorithm as the default / fallback.
  - Detect if user grants location permission (via new Info.plist key + runtime check).
  - Fetch geo-coordinates once per session, use them to override manual lat/long.
  - No change to resolver logic: schedule only cares about lat/long, not *how* they were obtained.

## Implementation

- `SolarCalculator.swift` — pure `SolarCalculating` protocol; `sunrise(lat:long:date:in:)` and `sunset(lat:long:date:in:)` return `SolarEvent` (`.event(Date)` or `.noEvent`).
- Computation happens in UTC, then localized via `TimeZone` to the user's timezone.
- Scheduled via `Scheduler.isScheduleActive(at:schedule:)`, which queries the calculator once at startup and on wake from sleep, avoiding re-computation.
- Tests exercise equatorial, mid-latitude, and polar regions; golden values can be added against NOAA calculator reference once algorithm is validated in production.

## References

- **NOAA Solar Calculation**: https://gml.noaa.gov/grad/solcalc/calcdetails.html
- **NOAA Equations PDF**: https://gml.noaa.gov/grad/solcalc/solareqns.PDF
- **Almanac for Computers, 1990**: Used by most reference implementations; compact 10-step procedure.
- **ceeK/Solar**: https://github.com/ceeK/Solar — MIT licensed Swift port, Foundation-only, excellent reference.
- **SunCalc**: https://github.com/mourner/suncalc — BSD-2 licensed JS reference; ±15 s rise/set accuracy.
- **NREL SPA**: https://research-hub.nrel.gov/en/publications/solar-position-algorithm-for-solar-radiation-applications-revised — Research-grade, overkill but available if needed.

## Approval

✅ **Accepted** by team decision to prioritize privacy, simplicity, and offline-first operation over automatic location detection.
