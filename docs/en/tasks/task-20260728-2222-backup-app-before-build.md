# Back Up the Existing App Before Building

## Goal

Before each build, back up an existing `dist/PomodoroBar.app` in the same directory.

## Changes

- Append a timestamp to the original name, for example `PomodoroBar.app.20260728-213000`.
- Store the backup in `dist/`.
- Generate the new application after the backup finishes.

## Affected Files

- `scripts/build.sh`
- `docs/tasks/task-20260728-2222-backup-app-before-build.md`

## Estimated Code Changes

Approximately 10 lines.

## Actual

Implemented. Before building, an existing `dist/PomodoroBar.app` is backed up as `PomodoroBar.app.YYYYMMDD-HHMMSS`. `./scripts/build.sh` passed and a backup directory was verified.
