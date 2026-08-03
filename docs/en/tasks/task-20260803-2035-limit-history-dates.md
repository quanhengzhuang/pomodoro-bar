# Limit History Date Menus

## Goal

Limit the length of the history menu and show the weekday in each date title.

## Changes

- Expand only the 30 most recent dates that contain records.
- Format date titles as “YYYY-MM-DD weekday (X records)”.
- When older records exist, show “Older Records (X days)...” at the bottom of the history menu and open the records file when selected.
- Keep the history summary counts based on all historical dates and records.

## Affected Files

- `Sources/main.swift`
- `docs/tasks/task-20260803-2035-limit-history-dates.md`
- `docs/en/tasks/task-20260803-2035-limit-history-dates.md`

## Estimated Code Changes

Approximately 20–35 lines.

## Verification Focus

- With 1000 historical dates, generate only 30 date submenus and report the remaining 970 older dates correctly.

## Actual Changes

- The history menu expands at most the 30 most recent dates containing records while keeping complete day and record totals.
- Date titles include the Chinese weekday; unparseable legacy dates retain their original date text.
- When the limit is exceeded, an “Older Records (X days)...” item opens the records file.

## Verification

- `./scripts/build.sh` completed successfully with only the existing notification API deprecation warnings.
- `2026-08-03` formats as Monday in Chinese, and a 1000-date simulation produces 30 date menus with 970 older dates.
