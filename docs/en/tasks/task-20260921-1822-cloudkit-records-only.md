# CloudKit Stores Timer Records Only

## Goal

Make CloudKit store only Pomodoro timer records while continuing to store and read Daily Guidance through the existing JSON files.

## Changes

- Remove CloudKit fetch, merge, and save logic for Daily Guidance.
- Keep the Daily Guidance JSON file and its local/iCloud Drive fallback behavior.
- Keep CloudKit synchronization and compatibility behavior for timer records.
- Update the related CloudKit documentation to state that Daily Guidance is not stored in CloudKit.

## Affected files

- `Sources/main.swift`
- `iOS/DailyGuidance/Shared/PomodoroCloudKitStore.swift`
- `docs/cloudkit-setup.md`
- `docs/en/cloudkit-setup.md`

## Estimated code lines

Approximately 40–70 lines.

## Result

Completed. CloudKit now reads and writes only `PomodoroSession`; Daily Guidance is stored only through `daily-guidance.json` and its iCloud Drive/local fallback copies. `./scripts/build.sh` passed; the iOS project could not be verified with `xcodebuild` because the environment has no full Xcode installation.
