# Paperweight

A lightweight macOS menu-bar app that lays a calm, paper-like texture overlay on every connected display to reduce glare and harsh contrast. No network calls, no telemetry, no focus stealing.

## Features

- **Zero network**: All processing runs locally; no external calls.
- **Zero telemetry**: No tracking, no analytics, no usage data collected.
- **Lightweight**: Flat memory usage (~10–20 MB) regardless of display count or resolution.
- **No CPU loop**: Idle CPU ≈ 0%. The overlay is static; redraws only on state changes.
- **Multi-monitor**: Works across all connected displays with per-display control.
- **Spaces & full screen**: Floats over full-screen apps and across all Spaces without forcing switches.
- **Customizable**: 12 presets (Comfort and Character) with adjustable intensity (Comfort slider).
- **Schedule**: Manual time-of-day or solar (sunrise/sunset) scheduling.
- **Exclusions**: Hide overlay when specific apps are frontmost.
- **Accessibility**: Respects "Reduce Transparency" system setting.
- **Launch at login**: Start automatically on login.

## Build

### Requirements

- macOS 13 Ventura or later
- Xcode 15+
- Homebrew (for xcodegen)

### Local Build (Ad-Hoc Signing)

```bash
# Install xcodegen
brew install xcodegen

# Generate project and build
make release
```

This produces:
- `/path/to/build/Release/Paperweight.app` (unsigned, ad-hoc)
- `/path/to/build/Release/Paperweight.dmg` (installer)

### Running Unsigned

```bash
# Open the built app directly
open build/Release/Paperweight.app

# Or mount and run from DMG
open build/Release/Paperweight.dmg
cd /Volumes/Paperweight
open Paperweight.app
```

On first launch, macOS may prompt: "Paperweight cannot be opened because it is from an unidentified developer."

**To bypass:**
1. Right-click `Paperweight.app` in Finder
2. Select "Open"
3. Click "Open" in the dialog

Alternatively, from the terminal:
```bash
xattr -d com.apple.quarantine build/Release/Paperweight.app
open build/Release/Paperweight.app
```

### Signed & Notarized (Optional)

If you have an Apple Developer account and signing identity:

```bash
# Set your signing identity (e.g., "Developer ID Application: Your Name")
export IDENTITY="Developer ID Application: Your Name"

# Build and sign
make release
make notarize
```

Note: Full notarization requires Apple Developer credentials and is performed via `xcrun altool` or similar. This is optional for internal use.

## Development

### Generate & Build

```bash
make generate   # Regenerate Xcode project from project.yml
make build      # Build the app
make test       # Run all unit tests (89+ tests)
make clean      # Clean artifacts
```

### Project Structure

```
paperweight/
├── project.yml           # XcodeGen project spec
├── Makefile              # Build targets
├── Sources/
│   ├── App/              # Entry point, MenuBarExtra, lifecycle
│   ├── Overlay/          # Window and panel management
│   ├── Engine/           # Texture generation and caching
│   ├── Control/          # Coordinator, schedule, exclusion
│   ├── Settings/         # Persistence and migration
│   └── UI/               # Preferences, menu bar panel, onboarding
├── Tests/                # Unit tests (89+)
├── Resources/
│   ├── Assets.xcassets/  # AppIcon, menu-bar glyph
│   ├── Fonts/            # JetBrains Mono bundled
│   └── Shaders/          # Metal shader for noise
└── docs/
    ├── ARCHITECTURE.md   # Module map and data flow
    ├── BUILD_LOG.md      # Development log
    └── adr/              # Architecture Decision Records
```

### Key Components

- **TextureEngine**: Generates seamless noise tiles (Metal GPU or Core Image fallback) and caches them.
- **OverlayController**: Reconciles one borderless panel per display; applies textures and opacity.
- **OverlayResolver**: Pure function implementing the full state→visibility precedence logic.
- **AppCoordinator**: Observes all inputs (user, schedule, ambient); triggers resolver and applies result.
- **SettingsStore**: UserDefaults-backed typed settings with backward-compatible schema migrations.

## Architecture

See `docs/ARCHITECTURE.md` for module map, data flow, and lifecycle diagrams.

See `docs/adr/` for detailed decisions on window level, noise strategy, memory, and more.

## Testing

All 89+ tests pass:
```bash
make test
```

Tests cover:
- Resolver precedence logic
- Panel reconciliation
- Settings round-trip and migrations
- Noise determinism and seamlessness
- Solar calculation
- Exclusion matching
- Preset library validation

## Network Audit

**Paperweight makes zero network calls.**

To verify:
```bash
# Build the app
make build

# Check for URLSession, Network, CFNetwork imports/symbols
nm build/Release/Paperweight.app/Contents/MacOS/Paperweight | grep -i "urlsession\|cfnetwork"

# Expected: (no output)

# Or use static grep on source
grep -r "URLSession\|URL(string:\|CFNetwork\|import Network" Sources/
# Expected: (no output, except possibly in comments)
```

All networking-related Foundation symbols are not linked into the binary.

## Accessibility

- Respects the system **Reduce Transparency** accessibility setting: overlay steps down comfort or switches to flat matte.
- Does not require Screen Recording permission (overlay composites on top; no screen sampling).
- Keyboard shortcuts for preferences and menu panel.

## Performance

- **Memory**: Target <25 MB resident, ceiling 50 MB (one ~512 KB tile repeated via CGPattern).
- **CPU**: Idle CPU ≈ 0% (no render loop; static layer after generation).
- **GPU**: Metal shader compiles once; GPU composites the static layer.

## License

Paperweight is internal-use software. Copyright © 2026 AI-First Consulting.

**JetBrains Mono** (bundled) is licensed under the [OFL 1.1](https://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=OFL).

## Troubleshooting

### App not appearing in menu bar
- Check System Settings → General → Login Items to confirm it's set to launch at login (if desired).
- Try quitting and relaunching: `killall Paperweight; open build/Release/Paperweight.app`

### Overlay not visible
- Check the menu bar glyph; click it to see the dropdown panel.
- Confirm the on/off toggle is enabled (should show a checkmark or highlight).
- Check Preferences → General → Per-Display Settings to ensure the display is enabled.

### Performance issues
- Check Instruments (Activity Monitor) for CPU usage; should be near 0% at idle.
- Check Preferences → Schedule to confirm no polling is active (one-shot timer only).

### Symbol/Glyph appears blurry
- This is expected on non-Retina displays. The overlay adjusts to each display's `backingScaleFactor`.

## Credits

- **Paperweight** © 2026 AI-First Consulting
- **JetBrains Mono** © JetBrains, licensed OFL 1.1
- Gruvbox Dark color palette by PavelKulagin
