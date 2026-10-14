# Create a Trip from Photos

## Goal

Open photo selection from the home plus button and assign a random title after saving.

## Changes

- Open the existing photo picker from the plus button and empty state, without asking for a title first.
- Save the trip and photo references together; do not create an empty trip if every photo fails.
- Pick a random title from preset trip names while keeping renaming available.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `docs/tasks/task-20261014-1909-create-trip-from-photos.md`
- `docs/en/tasks/task-20261014-1909-create-trip-from-photos.md`

## Estimated Lines of Code

About 70–100 lines.
