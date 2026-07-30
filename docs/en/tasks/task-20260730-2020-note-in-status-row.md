# Show the Note in the Status Row

## Goal

After setting a session note, show it in the first menu status row.

## Changes

- Append the current `sessionNote` to the first menu row.
- Show nothing when the note is empty.
- Refresh the first menu row immediately after editing the note.

## Affected Files

- `Sources/main.swift`
- `docs/tasks/task-20260730-2020-note-in-status-row.md`

## Estimated Code Changes

Approximately 5 lines.

## Actual Changes

- Appended the current `sessionNote` after the time in the menu status row.
- Added no separator or placeholder when the note is empty.
- Reused the existing menu rebuild path after saving or clearing the note so the status row refreshes immediately.

## Verification

- `./scripts/build.sh` completed successfully.
- `git diff --check` passed.
- The build only reports the existing `NSUserNotification` API deprecation warnings.
