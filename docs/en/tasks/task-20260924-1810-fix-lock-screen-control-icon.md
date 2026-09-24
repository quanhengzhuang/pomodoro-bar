# Fix the Lock Screen Control Icon

## Goal

Fix the question-mark icon shown by the Lock Screen control so it reliably displays a tomato icon.

## Changes

- Replace the custom SwiftUI drawing in the control with a static icon resource supported by WidgetKit.
- Keep the tomato's red, orange ring, and green leaf visual elements consistent with the Live Activity.
- Leave the control's launch action, timer logic, and record data unchanged.

## Impacted Files

- `iOS/Pomodoro/PomodoroLiveActivity/PomodoroLockScreenControl.swift`
- `iOS/Pomodoro/PomodoroLiveActivity/Assets.xcassets/`
- `iOS/Pomodoro/Pomodoro.xcodeproj/project.pbxproj`

## Estimated Code Lines

Approximately 10–30 lines of Swift and project configuration, plus a new icon resource set.

## Validation Focus

Confirm that the control no longer shows a question mark, displays the tomato after being re-added, and still opens the app when tapped.
