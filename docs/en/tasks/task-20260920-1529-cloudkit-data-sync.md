# Full CloudKit Data Sync

## Goal

Use the CloudKit private database to sync Pomodoro records and daily guidance between macOS and iOS while retaining all original JSON data.

## Changes

- Add a shared CloudKit data layer that syncs individual sessions and individual guidance dates.
- Configure macOS and iOS to use the same CloudKit container and required capabilities.
- On first enablement, merge legacy JSON with CloudKit, deduplicate, and upload through an idempotent migration.
- Retain `records.json` and `daily-guidance.json`, create an additional pre-migration backup, and continue using JSON as a readable local backup.
- Add offline caching, foreground refresh, merge deduplication, conflict retries, and user-facing errors.
- Document CloudKit schema deployment and legacy-data recovery.

## Affected Files

- `Sources/main.swift`
- `scripts/build.sh`
- `Packaging/`
- `iOS/DailyGuidance/DailyGuidance/PomodoroStore.swift`
- `iOS/DailyGuidance/DailyGuidance/GuidanceStore.swift`
- `iOS/DailyGuidance/DailyGuidance/DailyGuidance.entitlements`
- `iOS/DailyGuidance/DailyGuidance.xcodeproj/project.pbxproj`
- `iOS/DailyGuidance/Shared/`
- `README.md`
- `docs/en/README.md`
- `docs/cloudkit-setup.md`
- `docs/en/cloudkit-setup.md`
- `docs/code-reading-guide.md`
- `docs/en/code-reading-guide.md`

## Estimated Lines of Code

About 500–700 lines.

## Notes

- “All data” means completed Pomodoro records and daily guidance. Active timers, Live Activity state, and device preferences remain local so that devices cannot unexpectedly take over one another's timers.
- New records use stable UUIDs; legacy records derive a compatible ID from existing fields without changing the JSON semantics.
- The macOS app is currently compiled directly by a script. CloudKit requires a valid App ID, container, entitlements, and Apple Development signing.
- The migration never clears, deletes, or overwrites an original file that cannot be decoded.
