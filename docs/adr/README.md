# Architecture Decision Records

This directory contains ADRs documenting major architectural decisions and tradeoffs made during Paperweight development.

| ADR | Title |
|-----|-------|
| [0001](0001-window-level-and-collection-behaviour.md) | Window level and collection behavior for Spaces/full-screen survival |
| [0002](0002-noise-metal-vs-coreimage.md) | Metal for noise generation vs. Core Image fallback |
| [0003](0003-tile-and-repeat-memory.md) | Seamless tile repeating via CGPattern for flat memory |
| [0004](0004-no-render-loop.md) | State-driven redraws only; no render loop or polling |
| [0005](0005-blend-mode-strategy.md) | Compositing filters (soft light, multiply, overlay, etc.) |
| [0006](0006-menu-bar-agent-architecture.md) | Menu-bar agent with `.accessory` activation policy |
| [0007](0007-solar-calculation-vs-corelocation.md) | Pure Meeus solar calculation; no CoreLocation permission |
| [0008](0008-exclusion-list-mechanism.md) | Exclusion list via NSWorkspace bundle ID matching |
| [0009](0009-persistence-and-settings-versioning.md) | UserDefaults with backward-compatible schema migrations |
