# ADR 0009: Persistence and Settings Versioning

**Date**: 2026-06-27  
**Status**: Accepted  
**Context**: Persist app settings across launches and evolve schema as features are added  
**Decision**: Single JSON blob stored in `UserDefaults` under one key; schema versioning with per-phase migration chain  

## Problem

The app accumulates settings over multiple phases: Phase 1 (basic enable/disable), Phase 2 (profile selection, comfort), Phase 4 (schedule), and Phase 5 (exclusions, battery, RT response, per-display). The design space includes:

1. **Separate UserDefaults keys** — each setting gets its own key, loose/unstructured.
2. **Single JSON blob** — one Codable `Settings` struct serialized to UserDefaults, with a `schemaVersion` field to detect old data.
3. **External database** — SQLite, Core Data, Realm, etc. for richer querying and offline-first sync.
4. **Cloud sync** — iCloud Keychain, CloudKit, or a backend service.

## Decision

Implement persistence as a single JSON blob in `UserDefaults` under a fixed key (`"paperweight.settings"`). Include a `schemaVersion` field in `Settings` to track schema evolution. Implement one migration function per version bump, chained from current version down to v1.

### Rationale

**Zero external dependencies**:
- `UserDefaults` is built-in; no extra frameworks or databases to ship/maintain.
- Codable + JSONEncoder/Decoder are standard library; no third-party serialization needed.
- Enables deterministic, fast testing (just create a temporary UserDefaults suite).

**Simple and transparent**:
- All settings in one place, easily inspectable via Terminal (`defaults read`).
- Debugging is straightforward: see exactly what's stored.
- No hidden tables, migrations, or schema versioning headaches.

**Scalable up to Phase 6**:
- Single blob handles v1 → v2 → v3 and beyond. Each phase adds fields to `Settings`; old data is migrated on first launch after upgrade.
- Codable's default behavior is safe: missing fields in old JSON default to init defaults, extra fields in new JSON are ignored.

**Suitable for this app's scale**:
- Paperweight stores <1 KB of data (booleans, strings, numbers, a small dict).
- No complex queries, transactions, or multi-user sync needed.
- Single-user, local-only storage is a feature (privacy).

### Trade-offs

**No advanced querying**:
- Can't easily ask "show me all profiles where blend mode is softLight" without deserializing the full blob.
- *Not a problem*: UI is simple; profile library is hardcoded, not user-generated.

**No transactional integrity**:
- If crash occurs mid-write, UserDefaults may be partially corrupted (rare but possible).
- *Mitigation*: Use atomic writes (encode to temp file, `mv` atomically) if this becomes an issue; for now, the simplicity wins.

**Single-user only**:
- Can't sync settings across multiple Macs via iCloud or a backend.
- *Acceptable*: Ticket makes no mention of multi-device support; privacy-first design implies no cloud sync.
- *Upgrade path*: If future versions need sync, can layer CloudKit on top without changing the local schema.

## Implementation

### Phase 1–2 Schema (v1)

```swift
struct Settings: Codable {
    var schemaVersion: Int = 1
    var isEnabled: Bool
    var selectedProfileID: String
    var comfort: Float
}
```

### Phase 4 Schema (v2)

- Add `schedule: ScheduleConfig`
- Bump `schemaVersion` to 2
- Migration: v1 → v2 sets `schedule = .off` for old data

```swift
struct Settings: Codable {
    var schemaVersion: Int = 2
    var isEnabled: Bool
    var selectedProfileID: String
    var comfort: Float
    var schedule: ScheduleConfig
}
```

### Phase 5 Schema (v3)

- Add `exclusions: [String]`, `pauseOnBattery: Bool`, `launchAtLogin: Bool`, `reduceTransparencyResponse: ReduceTransparencyResponse`, `perDisplay: [DisplayID: DisplaySetting]`
- Bump `schemaVersion` to 3
- Migration: v1 → v2 → v3 (chained)

```swift
struct Settings: Codable {
    var schemaVersion: Int = 3
    var isEnabled: Bool
    var selectedProfileID: String
    var comfort: Float
    var schedule: ScheduleConfig
    var exclusions: [String]
    var pauseOnBattery: Bool
    var launchAtLogin: Bool
    var reduceTransparencyResponse: ReduceTransparencyResponse
    var perDisplay: [DisplayID: DisplaySetting]
}
```

### Migration Strategy

- **SettingsStore** holds a static `migrate(from:to:)` function that checks incoming `schemaVersion` and applies the appropriate migration chain.
- Each migration is pure: takes old JSON (as a Decodable intermediate type) and returns new `Settings`.
- Migration is called in `SettingsStore.load()` if the loaded version is < current version.

Example chain for v3:

```swift
func migrate(from version: Int, data: [String: Any]) -> Settings {
    switch version {
    case 1:
        let v1 = migrateV1ToV2(data)
        return migrateV2ToV3(v1)
    case 2:
        return migrateV2ToV3(data)
    case 3:
        return data  // Already current
    default:
        return Settings()  // Fallback: corrupt data, reset to defaults
    }
}
```

### Test Coverage

- **Round-trip tests**: Encode Settings → decode → compare (validates Codable impl).
- **Migration tests**: Create v1 JSON blob (hard-coded), load via store, verify v2/v3 fields are populated correctly.
- **Default seeding**: Verify that first launch with no prior UserDefaults creates sensible defaults (isEnabled=true, selectedProfileID="eink-calm", etc.).
- **Corruption recovery**: If JSON is malformed, `SettingsStore.load()` catches the error and returns defaults (graceful degradation).

## References

- **UserDefaults**: https://developer.apple.com/documentation/foundation/userdefaults
- **Codable**: https://developer.apple.com/documentation/swift/codable
- **JSONEncoder/JSONDecoder**: https://developer.apple.com/documentation/foundation/jsonencoder

## Approval

✅ **Accepted**: Single-blob approach with schemaVersion migrations provides the simplicity and transparency this privacy-first app needs, while remaining scalable through at least Phase 6. Codable + UserDefaults is a proven pattern in production macOS apps.
