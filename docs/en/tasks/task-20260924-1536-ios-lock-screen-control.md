# Add an iOS Lock Screen Control

## Goal

Make Pomodoro available in the bottom Lock Screen control picker on iOS 18 and later.

## Changes

- Add a quick control with a Pomodoro icon to the existing Widget extension; by default, tapping it opens the main app.
- Preserve the existing Live Activity and iOS 16.1–17 behavior without changing timer state or record format.
- Document the OS requirement and setup steps in both READMEs.

## Impacted Files

- Widget definition and registration files under `iOS/Pomodoro/PomodoroLiveActivity/`
- `iOS/Pomodoro/Pomodoro.xcodeproj/project.pbxproj`
- `README.md` and `docs/en/README.md`

## Estimated Code Lines

Approximately 25–50 lines of Swift and project configuration, plus 6 lines of documentation.

## Validation Focus

Verify the iOS build and that the control can be added; actual Lock Screen display and tap behavior must be confirmed on an iOS 18+ device or simulator.
