# Restore Records as a Submenu

## Goal

Revert the popover experiment and restore the submenu version.

## Changes

- Show the 10 most recent records in the main menu.
- Show all records for the current day in a submenu.
- Use the system default menu font for records.

## Affected Files

- `Sources/main.swift`
- `docs/tasks/task-20260728-2211-records-submenu.md`

## Estimated Code Changes

Approximately 40 lines.

## Actual

Restored the submenu design. The main menu shows the 10 most recent records, the All Records submenu shows every record for the day, and records use the system menu font. `./scripts/build.sh` passed with only the existing notification API deprecation warnings.
