# Adjust Active Countdown Time

## Goal

Allow active countdowns to be extended with positive values and shortened with negative values.

## Changes

- Rename the menu item and dialog from “Extend Time” to “Adjust Time.”
- Accept non-zero integers from -180 through 180; positive values extend and negative values shorten the countdown.
- Adjust both remaining time and planned session duration so elapsed time does not jump.
- Require the adjusted remaining time to stay above zero; otherwise show a validation alert without changing the timer.
- Synchronize the Chinese and English TODO files and check completed items.

## Affected Files

- `Sources/main.swift`
- `TODO.md`
- `docs/en/TODO.md`
- `docs/tasks/task-20260805-2055-adjust-countdown-time.md`
- `docs/en/tasks/task-20260805-2055-adjust-countdown-time.md`

## Estimated Code Changes

Approximately 20–30 lines of code plus minor documentation updates.

## Actual Changes

- Renamed the menu item and dialog to “Adjust Time.”
- The input accepts non-zero integers from -180 through 180 and still defaults to 5; positive values extend and negative values shorten the countdown.
- Remaining time and planned duration are adjusted together, and shortening must leave more than zero seconds remaining.
- The Chinese and English TODO items are checked.

## Verification

- `./scripts/build.sh` completed successfully with only the existing notification API deprecation warnings.
- `git diff --check` passed, and no references to the old extension methods remain in the source.
