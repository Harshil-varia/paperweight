# Paperweight Architecture

## Module Map

```
App
├── PaperweightApp (entry point, MenuBarExtra, Preferences window)
├── AppDelegate (lifecycle, font registration, screen monitoring)
└── Engine (TextureEngine for tile generation and caching)

UI
├── MenuBarPanel (menu bar dropdown: on/off, comfort slider, quit)
├── PreferencesView (tabbed: General, Textures, Schedule, Exclusions, About)
├── OnboardingView (first-run panel with benefit statement)
└── Theme (Gruvbox Dark design tokens and helpers)

Overlay
├── OverlayController (reconciles panels to screens, applies state)
├── OverlayPanel (borderless NSPanel at .screenSaver level)
└── OverlayLayerView (CALayer view with CGPattern tiling)

Engine
├── TextureEngine (generates noise tiles via Metal or Core Image)
├── MetalNoiseGenerator (GPU noise: white, value, Perlin, Simplex, fBm, ridged, Worley)
├── CoreImageNoiseGenerator (CPU fallback via Core Image)
├── TextureProfile (preset library: 12 presets with noise/blend/opacity config)
└── TileCache (in-memory + on-disk PNG caching)

Control
├── AppCoordinator (orchestrates all inputs → resolve → overlay apply)
├── OverlayResolver (pure precedence function: visibility, profile, opacity)
├── SolarCalculator (sunrise/sunset from lat/long/date)
├── Scheduler (one-shot timer for schedule boundaries)
├── SnoozeTimer (one-shot timer for snooze window)
├── ExclusionService (watches frontmost app, matches bundle IDs)
├── PowerMonitor (observes battery state)
├── ReduceTransparencyMonitor (observes accessibility settings)
└── LaunchAtLoginService (SMAppService wrapper)

Settings
├── Settings (typed struct: all user preferences + schema version)
├── SettingsStore (UserDefaults persistence + migration)
└── ScheduleConfig (enum: off / manual / solar)

Tests
├── OverlayResolverTests (precedence logic)
├── OverlayControllerTests (panel reconciliation)
├── SettingsStoreTests (round-trip + migrations v1→v2→v3)
├── NoiseDeterminismTests (seed reproducibility across all types)
├── TileSeamlessnessTests (edge matching, no tiling artifacts)
├── TileCacheTests (hit/miss, key variance)
├── SolarTests (sunrise/sunset golden values, polar edge cases)
├── SchedulerTests (schedule logic)
├── ExclusionTests (bundle ID matching)
├── PresetLibraryTests (all 12 presets validate)
└── [other unit tests]
```

## Data Flow: State Change → Pixels

### 1. Input Sources

Continuous observation of:
- **User input**: menu bar toggle, sliders, button clicks, preferences
- **Schedule**: one-shot timer fires at manual boundaries or solar sunrise/sunset
- **Ambient**: battery state, accessibility Reduce Transparency, frontmost app, screen changes

### 2. Coordinator Loop

```
┌─────────────────────────────────────┐
│ Input (settings, schedule, ambient) │
└──────────────┬──────────────────────┘
               │
               ▼
         AppCoordinator:
      (updates @Published var settings)
               │
               ├─► OverlayResolver.resolve(inputs)
               │   └─► pure: ResolvedOverlay
               │
               ├─► Emit @Published var resolved
               │
               └─► OverlayController.apply(resolved)
                   ├─► Reconcile panels to screens
                   ├─► TextureEngine.tile(for: profile, scale:)
                   │   ├─► Cache hit → return cached
                   │   └─► Cache miss → generate via Metal/Core Image
                   │
                   └─► Apply to each OverlayPanel:
                       ├─► Set CGPattern from tile
                       ├─► Set opacity
                       └─► Re-assert window level + frame

```

### 3. Resolver Precedence

`OverlayResolver.resolve()` applies the full decision tree in order:

1. **Exclusion**: if `excludedAppFrontmost && isEnabled` → `isVisible = false`
2. **Snooze**: if `snoozedUntil.isActive && isEnabled` → `isVisible = false`
3. **Schedule**: if not active → `isVisible = false`
4. **Battery pause**: if `onBattery && pauseOnBattery && isEnabled` → `isVisible = false`
5. **Reduce Transparency**: if enabled, step down `comfort` by 50% or switch to flat matte
6. **Per-display**: check `perDisplay[screenID].isEnabled` for each screen separately

Result: `ResolvedOverlay { isVisible, profileID, effectiveOpacity, perDisplay }`

### 4. Panel Lifecycle

```
Screen Added
     │
     ├─► OverlayController.reconcile() called
     │
     ├─► Create new OverlayPanel if not present
     │
     ├─► Frame to NSScreen.frame + backingScaleFactor
     │
     └─► Apply current ResolvedOverlay

Screen Removed / Resolution Changed
     │
     ├─► OverlayController.reconcile() called
     │
     ├─► Close + remove panel
     │
     └─► Re-reconcile remaining screens

Device Sleep → Wake
     │
     ├─► AppCoordinator re-arms scheduler
     │
     └─► OverlayController re-asserts level + frames

Settings Changed
     │
     ├─► AppCoordinator.settings setter triggers recompute()
     │
     └─► Publish new resolved → apply to panels
```

## Critical Invariants

1. **No render loop**: every redraw traces to a discrete state change (display, settings, schedule, ambient)
2. **Flat memory**: one small seamless tile (~256–512 KB) cached; repeated via CGPattern; no full-screen bitmaps
3. **Idle CPU ≈ 0%**: Metal shader compiles once at runtime; static layer after that; wakes only on state change
4. **Click-through + focus-free**: `.accessory` activation policy, `ignoresMouseEvents`, collection behavior `.ignoresCycle`
5. **No network calls**: all logic runs locally; settings in `UserDefaults` only
6. **Settings schema v3**: backward-compatible migrations from v1, v2 preserve user data

## Key Design Decisions

See `docs/adr/` for detailed reasoning:
- **ADR-0001**: Window level `.screenSaver` + collection behavior for Spaces/full-screen survival
- **ADR-0002**: Metal for noise (quality, GPU efficiency) + Core Image fallback
- **ADR-0003**: Seamless tile + CGPattern repeating for flat memory
- **ADR-0004**: No render loop; state-driven redraws only
- **ADR-0005**: Blend modes via `compositingFilter` (soft light, multiply, overlay, etc.)
- **ADR-0006**: Menu-bar agent (no Dock, no focus, lightweight)
- **ADR-0007**: Solar calculation via pure Meeus algorithm; no CoreLocation permission
- **ADR-0008**: Exclusion list (bundle ID matching) watches own NSWorkspace center
- **ADR-0009**: Settings schema v3 with backward-compatible migration from v1, v2
