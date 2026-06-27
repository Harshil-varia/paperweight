# ADR 0005: Blend Mode Strategy — `compositingFilter` Mapping

**Status**: Accepted  
**Date**: 2026-06-27  
**Participants**: Implementation team  
**Decisions**: Use `CALayer.compositingFilter` to apply preset-specific blend modes via Core Image filter strings.

## Context

The texture overlay must apply a consistent, well-defined blend mode to the tiled noise pattern as it overlays the desktop. The blend mode is a per-profile property that determines how the noise pattern interacts with the background:

- **Soft Light**: gentle lifting of shadows with preservation of highlights; suitable for comfort-focused presets
- **Multiply**: darkens everything; suitable for decorative/atmospheric presets
- **Screen**: lightens the overlay by inverting and multiplying; suitable for subtle brightening effects
- **Overlay**: combines multiply and screen based on background value; suitable for dramatic effect presets

The overlay system uses `CALayer` for rendering (via `OverlayLayerView`), which supports `compositingFilter` — a property that accepts Core Image filter names as strings and applies them during the layer's render-to-texture pass. This is more efficient than off-screen rendering or CPU post-processing.

## Decision

Use `CALayer.compositingFilter` with the following mapping:

| Preset BlendMode | CIFilter String | Use Case |
|---|---|---|
| `.softLight` | `"CISoftLightBlendMode"` | Default comfort mode; gentle, universally flattering |
| `.multiply` | `"CIMultiplyBlendMode"` | Strong darkening; decorative/warm presets (Parchment, Mulberry, Concrete) |
| `.screen` | `"CIScreenBlendMode"` | Lightening effect; subtle/atmospheric presets (Fog, Silk) |
| `.overlay` | `"CIOverlayBlendMode"` | Dramatic mix of darken and lighten; Blueprint, high-character presets |

### Implementation in `OverlayLayerView`

The `OverlayLayerView` applies the blend mode when setting the pattern on the layer:

```swift
// In OverlayLayerView.swift
private func updatePattern(for profile: TextureProfile, tile: TileImage) {
    let pattern = CGPattern(…create pattern from tile…)
    let patternColor = CGColor(patternSpace: …, pattern: pattern)
    
    layer.backgroundColor = patternColor
    layer.compositingFilter = profile.blendMode.filterName
    layer.opacity = effectiveOpacity
}

// In TextureProfile.swift
extension BlendMode {
    var filterName: String {
        switch self {
        case .softLight:
            return "CISoftLightBlendMode"
        case .multiply:
            return "CIMultiplyBlendMode"
        case .screen:
            return "CIScreenBlendMode"
        case .overlay:
            return "CIOverlayBlendMode"
        }
    }
}
```

### Preset Assignments

The 13 presets are assigned blend modes as follows:

**Comfort row (functional)**:
- E-Ink Calm: `.softLight` (maximum comfort, neutral)
- Classic Matte: `.softLight` (reliable, minimal grain)
- Vellum Mist: `.softLight` (soft perlin, smooth)
- Blueprint: `.overlay` (precise, high contrast for technical feel)

**Character row (decorative)**:
- Parchment: `.multiply` (warm, aged paper feel)
- Mulberry: `.softLight` (rich, character-rich)
- Linen: `.softLight` (woven, neutral)
- Sand: `.screen` (fine grit, brightening)
- Cotton: `.softLight` (soft, even weave)
- Silk: `.screen` (smooth, subtle shimmer)
- Concrete: `.multiply` (rough, industrial)
- Velvet: `.softLight` (dark, absorptive, but soft)
- Fog: `.screen` (very subtle, atmospheric)

## Rationale

1. **Performance**: `CALayer.compositingFilter` applies blending at render time on the GPU, not via CPU post-processing or manual off-screen rendering. No additional bitmap allocations.

2. **Consistency**: Each preset's blend mode is part of its profile, versioned in `TextureProfile`, and persisted in settings. The same blend applies every time the profile is selected.

3. **Simplicity**: The mapping is straightforward — one enum value to one filter string. No complex state machine or mode negotiation.

4. **Flexibility**: New blend modes can be added by extending `BlendMode` and the mapping without changes to the overlay rendering pipeline.

5. **Accessibility**: Blend modes are "nice-to-have" character; if a filter string is invalid or unsupported, `compositingFilter` is simply ignored and the overlay renders at the default blend. This is graceful degradation.

6. **Live tuning**: In the debug Lab panel, the blend mode and other profile parameters can be edited live. Changes take effect immediately via the resolved-overlay recompute path.

## Alternatives Considered

### Metal compute filter
**Rejected**: Applying the blend mode as part of the noise kernel would require:
- Sampling the background every pixel (expensive, requires screen capture)
- Complex state management (which display, which region)
- Violates the "no screen reading" constraint (requires Screen Recording permission)

### Manual Core Image filter graph
**Rejected**: Building a full CI filter graph to composite the pattern would:
- Require off-screen rendering of the full tile
- Negate the memory savings of tile-and-repeat
- Add CPU overhead for every apply() call

### `CADisplayLink` + manual rendering
**Rejected**: Violates the no-render-loop constraint; the whole point is discrete state changes, not frame-driven updates.

## Consequences

- Every preset must have a valid `BlendMode` value.
- The `BlendMode` enum is part of the public profile API.
- If a filter string is invalid, it is silently ignored (graceful degradation).
- Blend mode changes in live tuning (Lab panel) trigger a new profile → recompute → overlay apply flow.

## References

- [CALayer.compositingFilter](https://developer.apple.com/documentation/quartzcore/calayer/compositingfilter)
- [Core Image Filter Reference](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/)
- [CISoftLightBlendMode](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/index.html#//apple_ref/doc/filter/ci/CISoftLightBlendMode) (and other blend filters)
