# Count-Up and Countdown Timers

## Goal

Support both count-up and countdown timing.

## Changes

- Make “Start” begin a count-up timer; disable it during an active timer and let “Pause/Resume” take over the Space shortcut.
- Show “Pause” and “End” while running, without “Reset”.
- Remove “Skip to Next Session”.
- Remove selection marks from focus and break choices and start the corresponding countdown when clicked.
- Disable “Start” during a countdown while keeping “Pause” and “End” available.
- Record an ended session after it reaches 5 minutes; show a no-record warning below 5 minutes.
- Target menu:
  - Status: `Focus/Break/Count Up · Not Started/Running/Paused · Time`
  - Start
  - Pause
  - End
  - Set Session Note...
  - Focus N Minutes
  - Break 5 Minutes
  - Long Break 15 Minutes
  - Set Focus Duration...
  - Completed Today...
  - Time Outside Pomodoro...
  - 10 Most Recent Records
  - All Records (X)
  - Record File...
  - Clear Records
  - Quit Pomodoro Timer

## Previous Behavior

- Only focus, short-break, and long-break countdowns were supported.
- “Start” only started or resumed the current countdown.
- “Reset” discarded current progress, and “Skip to Next Session” changed modes immediately; neither recorded an early ending.
- Only naturally completed countdowns were recorded.

## Affected Files

- `Sources/main.swift`
- `README.md`
- `docs/TODO.md`
- `docs/tasks/task-20260730-2015-count-up-timer.md`

## Estimated Code Changes

Approximately 120 lines.

## Actual Changes

- Added count-up timing from `00:00`, with the status row distinguishing Focus, Break, and Count Up.
- Show “Start” only before a session; switch to “Pause/Resume” and “End” during an active session. Space starts, pauses, or resumes according to state.
- Clicking Focus, Short Break, or Long Break starts that countdown directly. Mode switching and restarting are disabled during an active session.
- Removed “Reset” and “Skip to Next Session”; ending a timer restores the corresponding not-started state.
- Ending a session records it at 5 minutes or longer and shows a warning without recording below 5 minutes.
- Count-up records use the new `count_up` type and save the actual duration in minutes; existing JSON fields and old-record decoding remain unchanged.
- Included active count-up time in current timing calculations and documented the feature and record type in the README.

## Verification

- `./scripts/build.sh` completed successfully.
- `git diff --check` passed.
- The build only reports the existing `NSUserNotification` API deprecation warnings.
