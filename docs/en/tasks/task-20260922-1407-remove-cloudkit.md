# Remove CloudKit Integration

## Goal

Restore the storage and sync behavior from before CloudKit was introduced, without requiring a developer certificate to use timers and Daily Guidance.

## Changes

- Reverse the CloudKit integration and subsequent adjustments; restore the Mac JSON/iCloud Drive records and guidance flow, and the original iOS timer records and guidance file flow.
- Remove CloudKit-only code, signing entitlements, and build configuration; update bilingual documentation while retaining historical task documents.
- Do not delete or clear existing JSON. Check whether local JSON left by newer versions needs compatibility handling to avoid losing records during the rollback.

## Affected files

- `Sources/main.swift`, `scripts/build.sh`, `Packaging/PomodoroBar.entitlements`
- Stores, UI, project settings, and shared CloudKit files under `iOS/DailyGuidance/`
- `README.md`, `docs/en/README.md`, bilingual code-reading guides, and CloudKit setup notes
- Both versions of this task document

## Estimated code lines

Approximately 800–1,300 lines added or removed, primarily to reverse the integration.

## Result

Completed. The code and build configuration are restored to the state before CloudKit was introduced. Timer records and Daily Guidance continue to use JSON with iCloud Drive or local fallback storage. `./scripts/build.sh` passed. Historical CloudKit task documents remain as history, but CloudKit is no longer part of the current code flow.
