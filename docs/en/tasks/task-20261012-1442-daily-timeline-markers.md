# Daily Markers in the Photo Timeline

## Goal

Make the start of each day easy to spot in a multi-day trip and use color to flag long or short intervals.

## Changes

- Show a prominent date divider before the first photo of each day, with the full date, weekday, and trip day number in both large and compact modes.
- Number trip days by the dates that actually have photos.
- Use the device's current calendar and time zone to identify days. Group photos without a capture time under a separate “Time needed” heading.
- Keep the current chronological order and intervals across days. Update the dividers when a photo's time changes.
- Show intervals over 2 hours in warning yellow and intervals under 20 minutes in green. Keep the current blue at the thresholds and for other intervals. Apply this in both large and compact modes.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261012-1442-daily-timeline-markers.md`
- `docs/en/tasks/task-20261012-1442-daily-timeline-markers.md`

## Estimated Lines of Code

About 65–95 lines.
