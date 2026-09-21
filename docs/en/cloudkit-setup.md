# CloudKit Setup and Recovery

## Data Scope

The CloudKit private database syncs completed Pomodoro sessions only. Daily Guidance remains in the readable `daily-guidance.json`, shared through the local directory or iCloud Drive file. Active timers, Live Activity state, and device preferences remain local.

The container identifier is fixed at `iCloud.local.codex.PomodoroBar`. Its data belongs to the currently signed-in iCloud account and is not public to other users.

## First-Time Setup

1. In the Apple Developer portal, create or confirm the CloudKit container `iCloud.local.codex.PomodoroBar` for the team.
2. Associate both the iOS and macOS App ID `local.codex.PomodoroBar` with that container.
3. Open `iOS/DailyGuidance/DailyGuidance.xcodeproj` in Xcode, select the `PomodoroBar` target, choose the same team under Signing & Capabilities, and confirm that iCloud / CloudKit shows the container above.
4. Regenerate provisioning profiles with the iCloud entitlement. A profile created before this capability was enabled can cause device installation or CloudKit access to fail.
5. Run a development build and save one completed session so the Development environment creates the schema; Daily Guidance does not create a CloudKit record type.

The selected team must support the iCloud capability. If Xcode cannot create the container or provisioning profile, check the Apple Developer membership and App ID capabilities first.

## Schema

The first writes in the Development environment create these record types:

| Record Type | Record Name | Fields |
| --- | --- | --- |
| `PomodoroSession` | Stable JSON `id` | `startedAt` String, `endedAt` String, `date` String, `type` String, `durationSeconds` Int64, `note` String, `schemaVersion` Int64 |

After verifying the types and fields in the CloudKit Console Development environment, use Deploy Schema Changes to deploy the schema to Production. This must be done before a production release because clients cannot dynamically create record types in Production.

Pomodoro sessions use the private database, are deduplicated by stable ID, and are never deleted. Daily Guidance is not uploaded to CloudKit; edits continue to write to `daily-guidance.json`.

## Mac Development Signing

Running `./scripts/build.sh` directly produces an ad-hoc signed build that works offline but cannot access CloudKit. Testing Mac sync requires an Apple Development certificate and a macOS provisioning profile matching the App ID and CloudKit container:

```bash
POMODORO_CODESIGN_IDENTITY="Apple Development: Your Name (TEAM ID)" \
POMODORO_PROVISIONING_PROFILE="/absolute/path/to/profile.provisionprofile" \
./scripts/build.sh
```

## Original Files and Backups

Migration never deletes the original JSON files. The Mac continues maintaining `records.json` and `daily-guidance.json` in iCloud Drive or the local fallback directory, and copies them before the first upload to:

```text
~/.pomodoro-status-bar/Legacy Backups/<timestamp>/
```

iOS local copies and migration backups are inside the app container:

```text
Library/Application Support/PomodoroBar/
Library/Application Support/PomodoroBar/Legacy Backups/
```

You can inspect these files by downloading the App Container from Xcode's Devices and Simulators window. A `daily-guidance.json` selected through the configuration entry remains a human-readable copy and is not imported into CloudKit.

## Recovery

1. Quit the Mac and iOS apps, then copy the entire `Legacy Backups` directory to a safe location.
2. Take `records.json` or `daily-guidance.json` from the correct timestamp and restore it to the Mac's active data directory. Keep all other backups.
3. Reopen the Mac app. It derives stable IDs for legacy records without an `id` and merges local data with CloudKit.
4. iOS Daily Guidance can be re-imported through the configuration entry.

The app sends no CloudKit delete requests, so recovery is additive and merge-based. Before any irreversible cloud cleanup, export a backup and verify whether the CloudKit Console is showing the Development or Production environment.
