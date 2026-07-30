# Extend an Active Countdown

## Goal

Allow minutes to be added to an active countdown and fix the focus duration at 25 minutes.

## Changes

- Show “Extend Time...” for active or paused focus and break countdowns.
- Default the input to 5 additional minutes and accept values from 1 to 180 minutes.
- Increase both remaining time and planned session duration so elapsed time does not jump.
- Remove the Set Focus Duration menu, preference loading, and validation alert; keep focus fixed at 25 minutes.
- Update the Chinese and English README and TODO files.

## Affected Files

- `Sources/main.swift`
- `README.md`
- `docs/en/README.md`
- `docs/TODO.md`
- `docs/en/TODO.md`
- `docs/tasks/task-20260730-2111-extend-active-countdown.md`
- `docs/en/tasks/task-20260730-2111-extend-active-countdown.md`

## Estimated Code Changes

Add approximately 35 lines and remove approximately 45 lines of code plus minor documentation.

## Actual Changes

- Active or paused focus, short-break, and long-break countdowns show “Extend Time...”.
- The extension dialog defaults to 5 minutes and validates an integer from 1 through 180.
- Both remaining and planned session time increase, keeping elapsed time, early-end duration, and time outside Pomodoro continuous.
- Count-up timers do not show the extension action.
- Removed the focus-duration menu, preference reads/writes, and validation alert; focus is fixed at 25 minutes.
- Updated the Chinese and English README and TODO files.

## Verification

- No focus-duration preference or settings entry points remain in the source.
- `./scripts/build.sh` completed successfully.
- `git diff --check` passed.
- The build only reports the existing `NSUserNotification` API deprecation warnings.
