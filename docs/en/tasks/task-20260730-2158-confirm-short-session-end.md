# Confirm Ending Sessions Under 5 Minutes

## Goal

When ending a session shorter than 5 minutes, ask the user to confirm or cancel instead of ending immediately.

## Changes

- Show a confirmation alert when clicking “End” and the active duration is under 5 minutes.
- Confirm: end the session without saving a record.
- Cancel: keep the current timer state.
- Sessions over 5 minutes keep the existing save-and-end behavior.
- Mark the TODO item as done after implementation.

## Affected Files

- `Sources/main.swift`
- `TODO.md`
- `docs/en/TODO.md`
- `docs/tasks/task-20260730-2158-confirm-short-session-end.md`
- `docs/en/tasks/task-20260730-2158-confirm-short-session-end.md`

## Estimated Lines

About 25 lines.

## Result

Implemented. Sessions shorter than 5 minutes now ask for confirmation first; cancel keeps the current timer state, while confirm ends without saving a record. `./scripts/build.sh` passes.
