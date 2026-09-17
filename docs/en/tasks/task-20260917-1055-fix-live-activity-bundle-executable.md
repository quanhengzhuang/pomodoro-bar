# Fix Live Activity Extension Installation Failure

## Goal

Add a valid `CFBundleExecutable` to `PomodoroLiveActivity.appex` so the app can install on a physical device.

## Changes

Declare `CFBundleExecutable` in the Live Activity extension `Info.plist`, expanded from the build product name, then rebuild the iOS project to verify the generated plist.

## Impacted Files

- `iOS/DailyGuidance/PomodoroLiveActivity/Info.plist`
- `docs/tasks/task-20260917-1055-fix-live-activity-bundle-executable.md`
- `docs/en/tasks/task-20260917-1055-fix-live-activity-bundle-executable.md`

## Estimated Code Lines

About 1 configuration line.

## Verification Focus

- The generated `PomodoroLiveActivity.appex/Info.plist` contains a `CFBundleExecutable` matching the bundled binary.
- The iOS device build no longer fails with `MissingBundleExecutable`.

## Actual Changes

- Added `CFBundleExecutable = $(EXECUTABLE_NAME)` to the Live Activity extension `Info.plist`.

## Verification Results

- A signed build for the connected iPhone succeeded; the generated `CFBundleExecutable` is `PomodoroLiveActivity`, and the matching executable is present.
- Xcode validated the main app and embedded extension, and the repaired `PomodoroBar.app` installed successfully on the device without `MissingBundleExecutable`.
