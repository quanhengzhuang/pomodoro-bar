# Change the Early-End Record Threshold to 3 Minutes

## Goal

Change the minimum duration recorded when ending a session early from 5 minutes to 3 minutes.

## Plan

- Add one shared minimum recorded-session duration constant set to 3 minutes.
- Continue showing a confirmation when active time is under 3 minutes, and do not save the session when ending it.
- Save sessions with at least 3 minutes of active time.
- Update the alert text to say “under 3 minutes.”

## Affected Files

- `Sources/main.swift`
- `docs/tasks/task-20260805-1031-short-session-threshold.md`
- `docs/en/tasks/task-20260805-1031-short-session-threshold.md`

## Complexity

Low; approximately 5–10 lines of code, with no record data format changes.

## Actual Changes

- Added one shared minimum recorded-session duration constant set to 3 minutes.
- Early-ended sessions under 3 minutes require confirmation and are not saved; sessions at or above 3 minutes are saved normally.
- Updated the alert text from 5 minutes to 3 minutes.

## Verification

- `./scripts/build.sh` completed successfully with only the existing notification API deprecation warnings.
