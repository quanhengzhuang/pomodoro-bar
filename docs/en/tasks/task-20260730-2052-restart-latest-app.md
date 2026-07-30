# Restart into the Latest Version Automatically

## Goal

When running a newly built version, automatically exit an old instance with the same Bundle ID and start the new instance.

## Changes

- Add `scripts/restart.sh` to build first and then force a new instance with `open -n`.
- On startup, find and gracefully terminate other instances of `local.codex.PomodoroBar`.
- Document the restart command in the README and update the TODO.

## Affected Files

- `Sources/main.swift`
- `scripts/restart.sh`
- `README.md`
- `docs/TODO.md`
- `docs/tasks/task-20260730-2052-restart-latest-app.md`

## Estimated Code Changes

Approximately 35 lines of code plus minor documentation.

## Risks

- An unfinished timer in the old instance is not recorded; saved `records.json` data is unaffected.
- A normal double-click may only activate the old instance, so the automatic replacement flow uses `scripts/restart.sh`.

## Actual Changes

- On startup, the new instance uses `NSRunningApplication` to find other processes with the same Bundle ID and asks them to terminate gracefully.
- Added executable `scripts/restart.sh`, which reuses the build script and launches a new instance with `open -n`.
- Documented the restart command and unfinished-timer behavior in the README and marked the TODO complete.

## Verification

- `bash -n scripts/restart.sh` passed.
- `./scripts/build.sh` completed successfully.
- `git diff --check` passed.
- `scripts/restart.sh` was not executed during verification to avoid interrupting the current timer.
- The build only reports the existing `NSUserNotification` API deprecation warnings.
