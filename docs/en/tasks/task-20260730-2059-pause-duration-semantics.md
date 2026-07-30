# Exclude Paused Time from Session Duration

## Goal

Use active timer duration consistently for records and time outside Pomodoro, excluding paused time from the session and assigning it to time outside Pomodoro.

## Changes

- Add `durationSeconds` to records for exact active time excluding pauses while retaining `durationMinutes`.
- Display record duration from `durationSeconds` instead of deriving it from `endedAt - startedAt`.
- Calculate time outside Pomodoro as wall-clock elapsed time minus active timer duration, so pauses count as outside time.
- Update the README and both TODO versions after completion.

## Affected Files

- `Sources/main.swift`
- `README.md`
- `docs/en/README.md`
- `docs/TODO.md`
- `docs/en/TODO.md`
- `docs/tasks/task-20260730-2059-pause-duration-semantics.md`
- `docs/en/tasks/task-20260730-2059-pause-duration-semantics.md`

## Estimated Code Changes

Approximately 45 lines of code plus minor documentation updates.

## Data Compatibility

- For old records without `durationSeconds`, use `durationMinutes × 60` without deleting or overwriting other fields.
- Keep the readable `durationMinutes` field in JSON and store exact seconds additionally for new records.
