# Collapse and Expand Menu Records

## Goal

When there are many records for the day, show only the most recent entries by default and allow all entries to be expanded.

## Changes

- Show the 5 most recent records for the day by default.
- Show “Expand All Records” when there are more than 5, and “Collapse Records” after expansion.
- Keep expansion state only for the current application run and do not write it to the data file.

## Affected Files

- `Sources/main.swift`
- `docs/tasks/task-20260728-2149-collapsible-records.md`

## Estimated Code Changes

Approximately 25 lines.

## Actual

Implemented. `./scripts/build.sh` passed with only the existing notification API deprecation warnings.
