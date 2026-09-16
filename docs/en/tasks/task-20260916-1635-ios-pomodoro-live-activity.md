# iOS Pomodoro Timer and Dynamic Island

## Goal

Expand the existing iOS viewer into a complete Pomodoro Bar iOS app and keep the timer visible in the Dynamic Island and on the Lock Screen through a Live Activity.

## Changes

- Upgrade and rename the existing SwiftUI iOS project to “Pomodoro Bar” while preserving Daily Guidance file selection, reading, and the current uncommitted access-permission fix.
- Implement count-up timing, 25-minute focus, 5/15-minute breaks, and start, pause, resume, countdown adjustment, note, and end actions; derive progress from absolute timestamps and restore unfinished sessions.
- Use a tomato-slice progress ring as the main visual, showing the current mode, time, today's totals, and recent records with dark mode, Dynamic Type, and accessibility support.
- Add an ActivityKit/WidgetKit Live Activity for compact, minimal, and expanded Dynamic Island regions plus the Lock Screen; synchronize or end it when the timer starts, pauses, resumes, changes, or ends.
- Send local notifications on completion; retain the existing readable JSON fields and duration semantics while storing iOS records in a separate app-sandbox file without changing or deleting Mac data.
- Raise the minimum version to iOS 16.1, add Live Activity, notification, and Widget Extension configuration, and update both READMEs.

## Affected Files

- `iOS/DailyGuidance/DailyGuidance.xcodeproj/project.pbxproj`
- `iOS/DailyGuidance/DailyGuidance/`
- `iOS/DailyGuidance/PomodoroLiveActivity/`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260916-1635-ios-pomodoro-live-activity.md`
- `docs/en/tasks/task-20260916-1635-ios-pomodoro-live-activity.md`

## Estimated Code Changes

Approximately 700–1,000 lines of Swift, project configuration, and minor documentation updates.

## Compatibility and Verification Focus

- Preserve the existing `records.json` fields, record types, and second-level duration semantics; do not migrate or overwrite Mac records or Daily Guidance data.
- Verify foreground/background transitions, process relaunch, midnight rollover, pause/resume, countdown completion, the Live Activity lifecycle, and Lock Screen presentation on devices without a Dynamic Island.
- Use the existing development-team setting for device builds; final Dynamic Island behavior requires validation on a supported physical iPhone.

## Actual Changes

- Upgraded the iOS target to Pomodoro Bar with a tomato-slice progress ring, four timer modes, start/pause/resume/end actions, duration adjustment, notes, today's summary, and recent records.
- Timer state is derived from absolute timestamps and accumulated paused time; active sessions persist in `UserDefaults` for relaunch recovery, while records use the existing fields in readable JSON inside the iOS app's separate sandbox.
- Added a Widget Extension and ActivityKit Live Activity for the Lock Screen plus minimal, compact, and expanded Dynamic Island presentations; pause, resume, adjustment, and end actions synchronize the state.
- Schedules a local completion notification while a countdown is running, cancels it on pause or manual end, and presents notification banners in the foreground.
- Retained the Daily Guidance entry point and read-only file authorization flow, raised the minimum version to iOS 16.1, enabled Live Activities, and updated both READMEs.

## Verification Results

- Both the main app and Live Activity extension passed Swift type checking against an iPhoneOS 16.1 target; the Xcode project and extension `Info.plist` passed format validation.
- Xcode recognizes the `PomodoroBar` and `PomodoroLiveActivity` targets, and the extension Swift sources compile successfully.
- `./scripts/build.sh` built the macOS app successfully with only the existing notification API deprecation warnings.
- A generic iPhone build was run; because this machine has no available iOS Simulator runtime, the asset compiler stopped final packaging. Dynamic Island layout and signed installation still require final verification on a supported physical iPhone.
