# ADR-0003: Seamless Tile + Compositor Repeat — Flat Memory Guarantee

**Status**: Accepted  
**Date**: 2026-06-27  

## Context

Rendering the overlay on a 5K display requires a 5120×2880×4 byte surface ≈ 57 MB. A single high-res monitor can already exceed the 50 MB memory ceiling if we allocate screen-sized bitmaps.

The solution must keep resident memory flat regardless of display size/count.

## Decision

**One small seamless tile, repeated by the compositor:**

1. **Tile generation**: `TextureEngine` produces a single 256–1024² seamless noise tile (~0.25–4 MB)
2. **Caching**:
   - Hot cache: in-memory `TileImage` (current profile)
   - Warm cache: on-disk PNG (previous sessions' profiles)
   - Cache key: `contentHash(profile, scale)` (deterministic, avoids re-generation)
3. **Rendering**:
   - Tile is set as `overlayLayer.contents` (a `CGImage`)
   - `contentsGravity = .topLeft` tells the layer to repeat the tile
   - Compositor tiles it across the full window bounds (no CPU buffer allocation)
   - `compositingFilter` (blend mode) applied by the renderer
   - `opacity` adjusted per `resolve()` output

**Per-display rendering**: Each `OverlayPanel` reads its own `window.backingScaleFactor`, so multi-monitor setups with mixed scales remain crisp.

## Consequences

- Resident memory: ~1 MB tile + hot cache + warm cache on disk (under 50 MB ceiling)
- Relaunch is instant: warm cache loads disk tile in milliseconds
- Profile change is one GPU generate + one cache write
- Tile seamlessness is critical (edge-mismatch causes visible tiling artifacts)
