# Move the Date into the Timeline Circle

## Goal

Show the date in the left circle of the large timeline and only the capture time below each photo.

## Changes

- Always show month, day, and year in each day's circular marker, rather than showing the year only for trips spanning multiple years.
- Change the large photo card time to `HH:mm`; keep the place on the same row and the missing-time prompt when needed.
- Show the time in blue to distinguish it from dark note text; keep the existing warning color for missing-time prompts.
- Leave compact mode's date display unchanged.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261012-1845-date-in-timeline-circle.md`
- `docs/en/tasks/task-20261012-1845-date-in-timeline-circle.md`

## Estimated Lines of Code

About 10–20 lines.
