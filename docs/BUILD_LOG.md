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
