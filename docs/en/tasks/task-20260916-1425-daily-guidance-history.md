# Daily Guidance History

## Goal

Add a Daily Guidance history entry below session history so guidance from the most recent 30 calendar days can be viewed by date.

## Changes

- Add a “Daily Guidance History” submenu below “History.”
- Include today and show only non-empty dates within the most recent 30 calendar days, sorted newest first.
- Show the date and weekday for each entry, with a submenu that displays the full content using the existing 520-point-wide warm-amber italic plain-text view.
- Show a clear empty state when no entries exist without changing the `daily-guidance.json` format or historical data.
- Update the Chinese and English READMEs.

## Affected Files

- `Sources/main.swift`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260916-1425-daily-guidance-history.md`
- `docs/en/tasks/task-20260916-1425-daily-guidance-history.md`

## Estimated Code Changes

Approximately 60–90 lines of code plus minor documentation updates.

## Actual Changes

- Added a “Daily Guidance History (Last 30 Days)” submenu directly below session History.
- Filters by local calendar day for the 30-day window including today, excluding empty content, invalid dates, future dates, and older entries, then sorts newest first.
- Each date displays its date and Chinese weekday; its submenu reuses the 520-point warm-amber italic plain-text view for the full content.
- Shows “No Daily Guidance History” when there are no qualifying entries and updates both READMEs.

## Verification Results

- `./scripts/build.sh` succeeded with only the existing deprecated notification API warnings.
- Verified menu placement, the 30-calendar-day boundary, empty-content filtering, descending order, and empty-state logic.
- The implementation only reads the merged in-memory values and does not change the format or content of `daily-guidance.json`.
