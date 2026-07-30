# Start or Pause with Space

## Goal

While the menu is open, press Space alone to start, pause, or resume the current timer.

## Changes

- Keep Space as the Start/Pause menu shortcut and explicitly remove Command and other modifier keys.
- Document the shortcut in the README and mark the corresponding TODO complete.

## Affected Files

- `Sources/main.swift`
- `README.md`
- `docs/TODO.md`
- `docs/tasks/task-20260730-2030-space-toggle-timer.md`

## Estimated Code Changes

Approximately 1 line of code plus minor documentation.

## Actual Changes

- `startPauseMenuItem` uses Space as its `keyEquivalent` with an empty `keyEquivalentModifierMask`.
- Space invokes the existing `toggleTimer()`: it starts before a session, pauses while running, and resumes while paused.
- Updated the README and marked the corresponding TODO complete.

## Verification

- `./scripts/build.sh` completed successfully and produced `dist/PomodoroBar.app`.
- `git diff --check` passed.
- The build only reports the existing `NSUserNotification` API deprecation warnings.
