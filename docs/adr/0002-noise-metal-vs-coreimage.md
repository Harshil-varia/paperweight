# ADR-0002: Noise Generation — Metal Primary, Core Image Fallback

**Status**: Accepted  
**Date**: 2026-06-27  

## Context

Noise generation must be:
- **Deterministic**: same seed → identical bytes (enables caching and testing)
- **Seamless**: edges match so tiles repeat perfectly without seams
- **Efficient**: runs once per (profile, scale, seed), cached thereafter
- **Portable**: fallback for machines without Metal device

## Decision

Primary path: **Metal compute kernel** (`Sources/Engine/MetalNoiseGenerator.swift` + `Resources/Shaders/Noise.metal`)
- Uses integer-lattice hashing (deterministic, no sin/cos)
- Periodic (seamless by construction)
- Supports full noise library (white, value, Perlin, fBm, ridged, Worley)

Fallback path: **Core Image** (`CoreImageNoiseGenerator.swift`)
- CIRandomGenerator (not fully deterministic, but sufficient for fallback)
- CIExposureAdjust for matte lift
- Handles machines without Metal

Bridge: `TextureEngine` facade chooses:
1. Try Metal; if device exists, use it
2. Fall back to Core Image if Metal fails
3. Return `nil` if both fail (graceful degradation)

## Shader compilation: runtime, not build-time metallib

The intended approach was to compile `Noise.metal` into the app's
`default.metallib` at build time. The development/CI machine, however, does
**not** have the offline Metal Toolchain installed (`xcodebuild
-downloadComponent MetalToolchain`), so a build-time `CompileMetalFile` step
fails outright.

Decision: keep `Noise.metal` as a **bundled resource** and compile it at
**runtime** via `device.makeLibrary(source:options:)`. Runtime compilation
uses the Metal framework (present on every Metal-capable Mac) and needs no
offline toolchain. `MetalNoiseGenerator` loads the bundled `Noise.metal`
source first and falls back to an embedded source constant only if the
resource is missing; if runtime compilation throws, it returns `nil` and the
engine cleanly falls back to Core Image.

If the Metal Toolchain becomes available, moving `Resources/Shaders` into the
target's compile `sources` (so it links into `default.metallib`) is a drop-in
swap — switch `makePipelineState` back to `makeDefaultLibrary()`.

## Consequences

- Tests verify determinism on Metal path (seeded hash correctness)
- Core Image path trades perfect determinism for portability
- No `sin()`-based hashing (avoids floating-point drift across platforms)
- Noise-type → shader code mapping uses a **stable** enum code (not
  `String.hashValue`, which Swift randomizes per process) so output is
  identical across launches
- Tile cache is keyed by content hash of profile + scale
