# Today and Record History Menus

## Goal

Split all records for today and historical records into two sibling submenus, with historical records grouped into third-level date submenus.

## Changes

- Rename the existing All Records item to “All Records Today (X)” and keep showing every record from today.
- Add a “History (X days / X records)” submenu.
- Sort historical dates newest first; each “YYYY-MM-DD (X records)” item opens a third-level submenu containing that date's records.
- Keep the 10 most recent records from today in the main menu; show disabled placeholders when a group is empty.

## Affected Files

- `Sources/main.swift`
- `docs/tasks/task-20260803-1812-record-history-menus.md`
- `docs/en/tasks/task-20260803-1812-record-history-menus.md`

## Estimated Code Changes

Approximately 35–50 lines.

## Actual Changes

- The main menu still shows the 10 most recent records from today and now always provides sibling All Records Today and History submenus.
- Historical records are grouped by date in newest-first order, with each date opening a third-level record submenu.
- Empty today or history menus show disabled placeholders; the record data format remains unchanged.

## Verification

- `./scripts/build.sh` completed successfully with only the existing notification API deprecation warnings.
