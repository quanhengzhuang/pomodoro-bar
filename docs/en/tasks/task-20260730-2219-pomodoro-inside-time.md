# Rename Today Completed To Time Inside Pomodoro

## Goal

Change the menu row “Today Completed” to “Time Inside Pomodoro”.

## Changes

- Remove the “Today Completed: X Pomodoros · Y sessions” row.
- Show today’s active timer duration instead: `Time Inside Pomodoro: X hours Y minutes`.
- Keep it paired with the existing “Time Outside Pomodoro” row.

## Affected Files

- `Sources/main.swift`
- `TODO.md`
- `docs/en/TODO.md`
- `docs/tasks/task-20260730-2219-pomodoro-inside-time.md`
- `docs/en/tasks/task-20260730-2219-pomodoro-inside-time.md`

## Estimated Lines

About 20 lines.

## Result

Implemented. The menu now shows “Time Inside Pomodoro” and “Time Outside Pomodoro”, both based on today’s active timer duration calculation. `./scripts/build.sh` passes.
