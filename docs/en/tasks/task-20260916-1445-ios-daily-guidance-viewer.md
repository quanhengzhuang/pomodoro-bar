# iOS Daily Guidance Viewer

## Goal

Add a simple iOS app that displays today's Daily Guidance from the existing `daily-guidance.json` in iCloud Drive.

## Changes

- Add a standalone SwiftUI iOS project named “Daily Guidance” inside the repository, targeting iOS 16 or later.
- On first launch, use the system file picker to select `iCloud Drive/PomodoroBar/daily-guidance.json`, retain access, and read it automatically on later launches.
- Read today's entry using the local date and display it as warm-amber italic plain text with multiline wrapping and scrolling.
- Provide refresh and file-reselection actions, with clear states for no selected file, no content today, unreadable files, and invalid JSON.
- Keep the app read-only: do not modify, migrate, or delete Mac data; reuse the existing application icon as the iOS icon source.
- Update the Chinese and English READMEs with the project location, data-selection flow, and device-signing instructions.

## Affected Files

- `iOS/DailyGuidance/DailyGuidance.xcodeproj/project.pbxproj`
- `iOS/DailyGuidance/DailyGuidance/`
- `.gitignore`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260916-1445-ios-daily-guidance-viewer.md`
- `docs/en/tasks/task-20260916-1445-ios-daily-guidance-viewer.md`

## Estimated Code Changes

Approximately 250–350 lines of Swift, project configuration, and minor documentation updates.

## Verification Focus

- Full Xcode is installed in the current environment, but no iOS Simulator runtime is available; source type checking is possible, while a complete app build is blocked at asset compilation by this environment limitation.
- Installing on a physical device requires selecting the user's own Apple Developer Team in Xcode; no changes to the existing iCloud data format are required.

## Actual Changes

- Added a standalone SwiftUI iPhone project that selects `daily-guidance.json` through the system file picker on first launch and retains access for later launches.
- Reads today's entry by local date and displays it as warm-amber italic plain text with multiline wrapping, scrolling, and text selection.
- Added toolbar refresh, pull-to-refresh, file reselection, and states for no file, loading, no entry today, unreadable files, and invalid JSON.
- Reused the tomato artwork for a complete set of iPhone app icon sizes and updated both READMEs with usage and signing instructions.

## Verification Results

- Swift sources passed type checking against the iPhoneOS SDK; the Xcode project, shared scheme, asset JSON, icon dimensions, and icon alpha channels all passed validation.
- `./scripts/build.sh` succeeded with only the existing deprecated notification API warnings.
- A generic iPhone Xcode build was run and Swift compilation started normally; because this machine has no iOS Simulator runtime, the asset compiler stopped before final app packaging.
