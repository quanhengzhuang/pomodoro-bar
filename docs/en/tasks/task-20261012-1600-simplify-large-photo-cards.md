# Simplify Large Photo Timeline Cards

## Goal

Show only essential information in large photo cards and open the system Maps app from a place.

## Changes

- Remove the edit icon. Tapping the photo, time, or note opens the editor.
- Show the date and time on one line, with a smaller place label to the right. Truncate long places while keeping the full place available through Maps.
- Tapping a place opens system Maps at its GPS coordinate, or searches a manually entered place when GPS is unavailable.
- Hide the note when empty and hide the place action when unavailable. Keep the prompt for a missing capture time.
- Make the place and editor separate tap targets so opening Maps does not open the editor.
- In large mode, replace each full-width day divider with a circular date marker to the left of the day's first photo (month/day, with a year when the trip spans years). Keep the current divider in compact mode and keep date jumping aligned with each day's start.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261012-1600-simplify-large-photo-cards.md`
- `docs/en/tasks/task-20261012-1600-simplify-large-photo-cards.md`

## Estimated Lines of Code

About 85–125 lines.

## Verification Focus

Check long place names, one-line time, empty notes, GPS and manual place links, cross-year date circles, and that map and edit taps do not interfere.
