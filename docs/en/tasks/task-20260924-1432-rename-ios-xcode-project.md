# Rename the iOS Xcode Project

## Goal

Rename the iOS Xcode project from `DailyGuidance.xcodeproj` to `Pomodoro.xcodeproj` to match the current Mac app name.

## Changes

- Rename the project bundle and update the shared scheme's project references, the project configuration name, and the path in both READMEs.
- Keep the existing `PomodoroBar` target, Bundle Identifier, App Group, and `DailyGuidance` source directory to preserve installed apps and data.
- Validate project references, build scripts, and project structure.

## Affected files

- `iOS/DailyGuidance/DailyGuidance.xcodeproj/` → `iOS/DailyGuidance/Pomodoro.xcodeproj/`
- `README.md`, `docs/en/README.md`
- Both versions of this task document

## Estimated code lines

Approximately 10–25 lines, plus the project directory rename.

## Result

Renamed the Xcode project to `iOS/DailyGuidance/Pomodoro.xcodeproj` and updated the shared scheme references, project configuration display name, and both READMEs. `xcodebuild -list` recognizes the `Pomodoro` project with the original two targets and two schemes; project and scheme formats and `./scripts/build.sh` passed. Bundle Identifier, App Group, and data directory remain unchanged.
