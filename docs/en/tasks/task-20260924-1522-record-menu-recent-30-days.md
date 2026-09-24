# Expand Today's Records and Show the Last 30 Calendar Days

## Goal

Show every record from today directly in the main menu; show history from only the last 30 calendar days while retaining all records in JSON.

## Changes

- Remove the “All Records Today” submenu and the 10-entry main-menu limit; show all of today's records in the existing order.
- Limit history to the 30 calendar days before today instead of the latest 30 dates with records; label it “Historical Focus Records (last 30 days / xxx records)” with the count limited to that range. Older records remain accessible through “Open Records File”. This changes the title only and does not add a record-type filter.
- Keep the “Daily Guidance Records (last 30 days)” menu title and its existing history and range unchanged.
- Remove “Open Records File” from the main menu; add bottom entries to the “Historical Focus Records” and “Daily Guidance Records” submenus to open `records.json` and `daily-guidance.json`, respectively, even when there are no entries.
- Replace the old “Older Records” jump with the history submenu's bottom file entry; the files continue to retain every date.
- Do not change record reading, writing, format, or historical contents in the file.

## Affected files

- `Sources/main.swift`
- Both versions of this task document

## Estimated code lines

Approximately 45–75 lines added or removed.

## Result

Completed: all of today's records appear in the main menu; “Historical Focus Records” shows only the 30 calendar days before today and counts records in that range, while “Daily Guidance Records” keeps its title and range. Each submenu has a bottom entry opening its complete JSON file. Record format and older dates are unchanged. `./scripts/build.sh` passed (with only existing deprecated notification API warnings).
