# Show Elapsed Time Consistently in the Status Row

## Goal

Show elapsed session time in the first menu row for both count-up and countdown timers.

## Changes

- Show the accumulated time directly for count-up timers.
- For countdown timers, show the planned duration minus the remaining time; show `00:00` before a session starts.
- Keep elapsed time unchanged while paused, and preserve the current countdown display in the menu bar itself.
- Update both Chinese and English TODO files after completion.

## Affected Files

- `Sources/main.swift`
- `docs/TODO.md`
- `docs/en/TODO.md`
- `docs/tasks/task-20260730-2056-elapsed-time-status.md`
- `docs/en/tasks/task-20260730-2056-elapsed-time-status.md`

## Estimated Code Changes

Approximately 8 lines of code plus minor documentation updates.

## Actual Changes

- The first menu row shows the accumulated time for count-up timers.
- During an active countdown, it shows the planned duration minus the remaining time; before starting, it shows `00:00`.
- The timer does not advance while paused, so elapsed time in the first row remains unchanged.
- The menu bar itself retains its existing display of accumulated count-up time or remaining countdown time.
- Synchronized the Chinese and English TODO files.

## Verification

- `./scripts/build.sh` completed successfully.
- `git diff --check` passed.
- The build only reports the existing `NSUserNotification` API deprecation warnings.
