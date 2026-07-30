# Show Record Time Ranges in the Menu

## Goal

Show the real start and end time for menu records while retaining the actual duration in minutes.

## Changes

- Change the record format to `2026-07-28 16:59-17:04 · Break · 5 minutes`.
- Append a note when present, such as `· Organize planning notes`.
- Continue omitting seconds and preserve the colored dot.

## Affected Files

- `Sources/main.swift`
- `docs/tasks/task-20260728-2136-record-time-range.md`

## Estimated Code Changes

Approximately 10 lines.

## Actual

Implemented. Menu duration is calculated from `startedAt` to `endedAt`, with `durationMinutes` used only when parsing fails. `./scripts/build.sh` passed with only the existing notification API deprecation warnings.
