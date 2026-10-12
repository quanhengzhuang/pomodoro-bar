# Year Dividers and Marker Spacing

## Goal

Group the large photo timeline by year while showing only month and day in each date circle, and restore breathing room around timeline markers.

## Changes

- Show a centered “— 2026 —” divider before the first point of each year, once per year.
- Remove the year from date circles, keeping their current size and spacing from the photo.
- Leave about 8 points of space above and below each circle or dot so the rail runs alongside cards and intervals without touching markers.
- Show only the elapsed time and distance values, removing the “since previous stop” prefix in both large and compact modes.
- Do not show a year for photos without a capture time; preserve compact mode's dates and date-jump targets.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261012-1907-year-timeline-divider.md`
- `docs/en/tasks/task-20261012-1907-year-timeline-divider.md`

## Estimated Lines of Code

About 40–60 lines.
