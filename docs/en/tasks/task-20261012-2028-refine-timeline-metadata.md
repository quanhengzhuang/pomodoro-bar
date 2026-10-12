# Refine Timeline Metadata Layout

## Goal

Make photo times, places, notes, and intervals easier to read without showing raw coordinates.

## Changes

- Use the same regular gray type for time and place, align places to the right, and hide places when only coordinates are available.
- Set notes to a size between the previous body and headline sizes.
- Show elapsed time to the minute, without seconds, and center large-mode intervals relative to the photo card.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261012-2028-refine-timeline-metadata.md`
- `docs/en/tasks/task-20261012-2028-refine-timeline-metadata.md`

## Estimated Lines of Code

About 30–50 lines.
