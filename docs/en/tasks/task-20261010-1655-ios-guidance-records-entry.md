# Adjust Daily Guidance and Focus Records on the iOS Home Screen

## Goal

Show today's guidance directly on the home screen and move focus records behind a dedicated entry.

## Changes

- Replace the home screen's “Recent Records” section with today's guidance, including unset, no-file, and read-error states, plus a clear “Edit” entry.
- Change the summary cell currently labeled “Daily Guidance” to “Focus Records”; tapping it opens a dedicated records list. Show an empty state when there are no records, without deleting or rewriting existing records.
- Keep the top-right quotation-mark entry and existing guidance screen; reuse the current JSON file access and timer-record data.

## Affected Files

- `iOS/Pomodoro/Pomodoro/ContentView.swift`
- Both versions of this task document

## Estimated Code Lines

Approximately 90–140 lines of Swift added or removed.

## Result

Completed: the home screen shows today's guidance with an “Edit” entry that opens today's editor directly. The “Focus Records” summary cell opens the full records list, and the top-right quotation-mark entry remains. No JSON or timer records were changed. Both the generic iOS device build and `./scripts/build.sh` passed; no simulator was launched.
