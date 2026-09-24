# Fix the Lock Screen Control and Match the Tomato Icon

## Goal

Make the “Open Pomodoro” control at the bottom of the Lock Screen reliably open the app and match the tomato mark used by the Live Activity.

## Changes

- Investigate and fix the launch action so both the main app and extension recognize it; tapping should still only open the app, never start a timer.
- Replace the generic timer symbol with the Live Activity's tomato shape, adapting it to Lock Screen control icon constraints.
- Check the installed control picker, Lock Screen tap behavior, and iOS build.

## Impacted Files

- `iOS/Pomodoro/PomodoroLiveActivity/PomodoroLockScreenControl.swift`
- `iOS/Pomodoro/PomodoroLiveActivity/PomodoroLiveActivity.swift` (if sharing the tomato mark)
- `iOS/Pomodoro/Pomodoro.xcodeproj/project.pbxproj` (if compiling the action into the main app or adding an icon resource)
- Possibly a new shared action file or extension icon asset

## Estimated Code Lines

Approximately 30–70 lines of Swift and project configuration; no changes to timer or record formats.

## Validation Focus

The current launch action appears only in the extension's Intent metadata, not the main app's; confirm that both recognize it after the fix and, if possible, verify on an iOS 18+ simulator that tapping actually opens the app.
