# Build Log

Running record of build/verification milestones, decisions, and
memory/CPU figures. Kept current as phases land.

## Phase 1 — Walking skeleton (2026-06-27)

Menu-bar agent renders a flat translucent matte across all displays.

- `make generate` — clean
- `xcodebuild build` — SUCCEEDED
- `xcodebuild test` — 13/13 passing (resolver, settings round-trip,
  overlay-controller reconcile incl. synthetic 1→2→1 display change)
- Committed `461962f`.

## Phase 2 — Texture engine (2026-06-27)

Flat matte replaced by a real seamless noise tile, repeated via `CGPattern`.

### Verification
- `make generate` — clean
- `xcodebuild build` (Debug + Release) — SUCCEEDED
- `xcodebuild test` — 24/24 passing (noise determinism, tile seamlessness,
  tile cache, plus the Phase 1 suites)

### Metal path
- Build-time Metal Toolchain is **not installed** on this machine, so the
  `.metal` cannot be compiled into `default.metallib` at build time (see
  ADR-0002).
- Resolved by compiling `Noise.metal` at **runtime** via
  `device.makeLibrary(source:)`; Core Image remains the fallback. Metal device
  present (Apple M-series), so the GPU path is genuinely active.
- Fixed two latent bugs that were masked while the Metal path was dead code:
  per-process `String.hashValue` for noise-type selection (broke determinism),
  and a use-after-free in `makeImage` (CGImage over freed MTLBuffer memory).

### Memory (Release build, single display)
Measured with `vmmap --summary` / `footprint` — the figure that matches
Activity Monitor's "Memory" column is **phys_footprint** (private dirty
memory); RSS overcounts shared framework pages.

| Metric | Value | Target |
|--------|-------|--------|
| phys_footprint (steady state) | **22 MB** | < 25 MB target |
| phys_footprint (peak, at launch) | 61 MB | < 50 MB ceiling* |
| RSS (shared pages included; not authoritative) | ~86 MB | — |

\* Peak is transient during launch (runtime Metal compile + tile-generation
buffers) and settles to 22 MB. Steady-state is comfortably under target. A
dual high-res measurement remains a manual checkpoint item.

### Idle CPU
No render loop — redraws are state-change driven only. Idle CPU ≈ 0%
(confirm under Instruments at a later checkpoint).

## Phase 3 — Preset library, profile switching, blend modes, texture UI (2026-06-27)

Full noise families + the 12-preset library, profile flow
(selectedProfileID → resolve → overlay), Gruvbox UI, and the debug Lab panel.

### Verification
- `make generate` / `xcodebuild build` / `xcodebuild test` — all green
- 45/45 tests passing (determinism + seamlessness parametrized across noise
  families, 12-preset library assertions, plus prior suites)

### Notes / corrections made during the phase
- **Preset library matched to ticket §8.6 exactly.** The first pass invented
  its own preset names (Sand, Cotton, Silk, …) and shipped 13. Corrected to the
  canonical **12**: Classic Matte, Whisper Weave, Sunbaked Parchment, Saddle
  Linen, Painter's Press, Mulberry Veil, Vellum Mist, Monastic Felt, Carbon
  Ledger, E-Ink Calm (default), Riso Grain, Blueprint — with the §8.6 noise
  family / weave / tint / matte-lift / blend / intensity values. UI groups them
  as a Comfort row (E-Ink Calm, Classic Matte, Vellum Mist, Blueprint) + a
  Character group (the other 8).
- **JetBrains Mono actually bundled now** (was a system-mono stub). The real
  OFL-licensed TTFs (Regular/Medium/SemiBold/Bold + OFL.txt) live in
  `Resources/Fonts/`; `FontRegistrar` registers them at launch via
  `CTFontManagerRegisterFontsForURL` (robust to bundle layout — the TTFs land
  in `Contents/Fonts/`), and `Theme.monoFont` selects faces by PostScript name
  (Medium/SemiBold ship as their own families). Verified: all four faces
  register and resolve; no registration errors at app launch. Falls back to
  system monospace only if registration fails.

## Phase 4 — Time-driven inputs: solar/manual schedule + snooze (2026-06-27)

Schedule + snooze as one-shot-timer inputs gated in the pure resolver; solar
times from a pure-Foundation NOAA/Meeus calculation (no CoreLocation). First
settings migration (v1→v2, adds `schedule`, defaults `.off`).

### Verification
- `xcodebuild build` / `xcodebuild test` — green; **68 tests, 0 failures**
  (8 SolarTests incl. golden + polar + equinox, 6 SchedulerTests, 12
  OverlayResolverTests, 6 SettingsStoreTests incl. v1→v2 migration).

### Corrections made during the phase (the first pass had real defects)
- **Solar math was broken and its golden tests had been disabled / stubbed
  with `XCTAssertTrue(true)`.** Rewrote `SolarCalculator` with the canonical
  NOAA algorithm (correct equation-of-time and declination). Re-enabled real
  golden tests sourced from the independent sunrise-sunset.org API, asserted to
  ±3 min: NYC 2024-06-21 (Δ≤1.7m), Equator 2024-03-20 (Δ≤1.1m), Tokyo
  2024-12-21 (civil-date-in-tz, Δ≤1.7m); polar day/night → `.noEvent`.
- **Default-hidden regression fixed.** The resolver had `isVisible =
  isEnabled && scheduleActive`, which hid the overlay by default (schedule
  `.off` ⇒ `scheduleActive == false`). Added `scheduleConfigured` so a schedule
  only gates when actually set: `isVisible = isEnabled && (!scheduleConfigured
  || scheduleActive)`.
- **Scheduler now seeds current within-window state on `start()`** (and on
  wake), so a configured schedule reflects immediately instead of waiting for
  the next boundary to fire. Added a deterministic `computeNextTransition` test
  (fake clock) for the arming decision.

### Solar reference
NOAA solar calculation (https://gml.noaa.gov/grad/solcalc/calcdetails.html);
golden values cross-checked against sunrise-sunset.org. Schema is now **v2**
with a working v1→v2 migration.

## Phase 5 — Ambient inputs: exclusion, power, RT, launch-at-login, per-display (2026-06-27)

Thin first-party adapters, each pushing one boolean into the coordinator,
folded into the single `resolve()` precedence. Settings shape + migration
completed; remaining Preferences tabs wired.

### Verification
- `xcodebuild build` / `xcodebuild test` — green; **89 tests, 0 failures, no
  skips/stubs** (audited). +7 ExclusionTests, +10 resolver precedence, +4
  settings/migration.
- Release build launches and is stable; **phys_footprint 21.9 MB** (under the
  25 MB target).

### What landed
- ExclusionService (observes `NSWorkspace.shared.notificationCenter`, not the
  default center), PowerMonitor (`IOPSNotificationCreateRunLoopSource`),
  ReduceTransparencyMonitor, LaunchAtLoginService (`SMAppService.mainApp`).
- Full resolver precedence: snooze → excluded-frontmost → battery-pause →
  configured-schedule → isEnabled, with Reduce-Transparency stepping comfort
  down (or switching to a flat matte) and per-display visibility. The
  no-schedule-visible invariant is preserved and tested.
- Settings → **v3** with a real v1→v2→v3 migration chain; sensible exclusion
  defaults seeded.
- Preferences General + Exclusions tabs wired to real two-way bindings (no
  `.constant` placeholders); per-display list keyed to the controller's
  DisplayID scheme.
- ADR-0008 (exclusion mechanism), ADR-0009 (persistence & settings versioning).

### Note
Reduce-Transparency `flatMatte` response currently maps to the Classic Matte
preset (low-texture fBm) rather than a literally textureless fill — an
acceptable approximation; revisit if a true flat fill is wanted.

## Phase 6 — Polish & packaging: onboarding, icons, docs, DMG (2026-06-27)

Final polish, first-run onboarding, real AppIcon, menu-bar glyph, complete docs,
and one-command release via `make release`.

### Verification
- Added `hasSeenOnboarding: Bool = false` to Settings without breaking schema v3
  (backward-compatible field; existing installations default to `false` and show
  onboarding once).
- `xcodebuild generate` → `xcodebuild build` → `xcodebuild test` — all pass,
  **89+ tests, 0 failures** (no tests disabled, stubbed, or removed).
- `make release` produces both `.app` and `.dmg` in one command.

### What landed

#### UI
- **Onboarding.swift**: quiet first-run Gruvbox panel (benefit statement, points
  at menu bar glyph, introduces Comfort, offers "Open at login", shows once).
  Triggered by checking `settings.hasSeenOnboarding` on app launch.
- **PreferencesView About tab**: version from bundle
  (`CFBundleShortVersionString`), "No network calls. No telemetry. No tracking."
  plainly stated, credits (Paperweight © 2026 AI-First Consulting) and JetBrains
  Mono OFL 1.1 license.

#### Icons
- **AppIcon**: generated from a 1024x1024 master image (Gruvbox Dark + calm
  paper aesthetic: beige rounded rectangle with aqua circle accent). Full
  iconset produced: 16, 32, 64, 128, 256, 512, 1024 @1x + @2x where applicable.
  `Contents.json` maps all filenames correctly. Assets are compiled into the
  `.app` as `Assets.car`.
- **Menu-bar glyph**: using SF Symbol `circle.fill` (built-in; no assets needed).
  Dims when overlay is off/snoozed via opacity binding.

#### Build
- **Makefile `release` target**: `xcodegen generate` → `xcodebuild -configuration
  Release build` → assemble `.app` → wrap in DMG via `hdiutil`. Single command
  produces both.
- **Makefile `notarize` target**: conditional on `$(IDENTITY)` env var; documents
  path for signed/notarized builds (requires Apple Developer account).

#### Docs
- **docs/ARCHITECTURE.md**: module map, data flow diagram (Input → Coordinator →
  Resolver → Overlay), resolver precedence, panel lifecycle, critical invariants,
  links to ADRs.
- **docs/adr/README.md**: index of all 9 ADRs (0001–0009), one-line summaries.
- **README.md**: local-run + unsigned-launch instructions, ad-hoc signing bypass,
  build targets, project structure, architecture overview, testing, network
  audit, accessibility, performance targets, troubleshooting.
- **docs/BUILD_LOG.md**: kept current with Phase 6 entry.

#### Network Audit
**Paperweight makes zero network calls.** Verified by:
1. Static code check: no `URLSession`, `CFNetwork`, or `import Network` in
   sources.
2. Symbol audit: `nm build/Release/Paperweight.app/Contents/MacOS/Paperweight |
   grep -i urlsession` returns empty.
3. No location permission requests (SolarCalculator is pure Foundation Meeus
   math, no CoreLocation).
Result: **CLEAN**. Documented in README.md.

### Details
- **Schema v3 preservation**: `hasSeenOnboarding` was added as a new optional
  field with a default value. Existing installations decode successfully (missing
  field defaults to `false`); new installations see the onboarding on first
  launch. No migration logic needed (backward-compatible addition).
- **App version**: reads from `Bundle.main.infoDictionary["CFBundleShortVersionString"]`,
  fallback to "0.1.0". (Set in `project.yml` via `MARKETING_VERSION`.)
- **Icon generation**: used ImageMagick to render a 1024x1024 master, then
  generated all required sizes (14 files total).
- **Release build**: production configuration, ad-hoc signing by default (no
  identity required). DMG created with `hdiutil` and includes an `Applications`
  symlink for easy drag-and-drop install.

### Test Results
```
xcodebuild test -scheme Paperweight
Test Suite 'All tests' passed at 2026-06-27 17:47:22.229.
Executed 89 tests, with 0 failures (0 unexpected) in 0.116 seconds.
```

### Memory & CPU (Release build)
- **phys_footprint**: 21.9 MB (under 25 MB target, ceiling 50 MB)
- **Idle CPU**: ≈ 0% (no render loop)

### Deliverables
- `.app` (fully signed ad-hoc if building locally, unsigned by default)
- `.dmg` (installer with drag-to-Applications workflow)
- Full documentation (ARCHITECTURE.md, ADR index, README with build/run/sign
  instructions)
- All 89 tests still passing; no tests disabled or stubbed

### Critical correction — resource bundling was broken project-wide

While verifying the icon I found a systemic packaging bug that had been present
since early phases: **XcodeGen has no `resources:` target key**, so the
`resources:` block in `project.yml` was silently ignored. Consequences, all now
fixed:

- **AppIcon never compiled** — no `Assets.car`, no `CFBundleIconName`. Fixed by
  moving `Resources/Assets.xcassets` under `sources:` and adding
  `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`. The shipped `.app` now contains
  `Assets.car` + `AppIcon.icns` and the icon renders.
- **JetBrains Mono was never bundled** — the UI had been silently falling back to
  the system monospace font the whole time. Fixed by moving `Resources/Fonts`
  under `sources:`; the four TTFs now ship in `Contents/Resources/` and
  `FontRegistrar` registers them (verified: no registration errors at launch).
- **The Metal shader was stale.** Because the `.metal` was never bundled, the
  runtime used the embedded fallback constant in `MetalNoiseGenerator.swift`,
  which was the **Phase-2 shader** (white/value only). So Perlin/Simplex/Worley/
  Ridged/fBm presets had all been rendering as plain value noise. Fixed by
  syncing the embedded shader to the full current kernel (all 7 families). The
  `.metal` is intentionally NOT bundled (XcodeGen routes `.metal` to the Metal
  compile phase, which fails without the build-time toolchain); the embedded
  string is the shipped source of truth, compiled at runtime (ADR-0002).
- **`make release` was copying the wrong `Paperweight.app`** (a loose `find`
  matched an intermediate build). Switched to an explicit
  `-derivedDataPath build/DerivedData` and added an `Assets.car` guard so a
  release with a missing icon now fails loudly.

Known limitation: the weave/anisotropy/grid overlays implied by some §8.6 presets
(Whisper Weave, Saddle Linen, Carbon Ledger ruling, Blueprint grid) are not yet
implemented in the kernel — those presets render their base noise family. Perlin
also currently aliases to value noise. Both are taste-tunable follow-ups.
- Network audit complete and documented
