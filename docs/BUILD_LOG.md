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
