# Fix iOS File Access Authorization

## Goal

Fix the “Unable to save file access permission” message after selecting `daily-guidance.json` from iCloud Drive on a physical iPhone.

## Changes

- Start the system-granted security-scoped file access before creating or renewing a bookmark, then release it promptly.
- Keep the app read-only without changing the JSON format or iCloud data.
- Preserve the user-selected Xcode development team and add a more useful failure message for diagnostics.

## Affected Files

- `iOS/DailyGuidance/DailyGuidance/GuidanceStore.swift`
- `docs/tasks/task-20260916-1631-ios-file-access-permission.md`
- `docs/en/tasks/task-20260916-1631-ios-file-access-permission.md`

## Estimated Code Changes

Approximately 15–25 lines of code plus task notes.

## Verification Focus

- The selected iCloud file can be read immediately on a physical device and remains accessible after relaunching the app.
- The development team setting is preserved, and the selected JSON file is never written or modified.

## Actual Changes

- Added one security-scoped access helper used before creating bookmarks, renewing stale bookmarks, and reading the selected file, with prompt access release afterward.
- Bookmark failures now include the specific system-provided reason to make physical-device issues easier to diagnose.
- Kept the selected file read-only and preserved the existing development team setting.

## Verification Results

- Swift source type checking passed, along with Xcode project and scheme validation.
- A generic iPhone Debug build succeeded, including asset compilation, Swift compilation, linking, and app validation.
- `./scripts/build.sh` succeeded with only the existing deprecated notification API warnings.
- First selection and retained access after relaunch still require confirmation after installing the new build on a physical device.
