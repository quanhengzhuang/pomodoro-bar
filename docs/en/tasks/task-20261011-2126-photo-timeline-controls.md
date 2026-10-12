# Photo Timeline Views and Deletion

## Goal

Show more timeline points per screen, allow photos to be removed from a trip, and fix Add Photos opening the first photo editor.

## Changes

- Add a Large / Compact switch above the timeline and remember the last selection. Compact rows show a thumbnail, time, note, and interval since the previous stop.
- Add a delete action with confirmation for timeline points. Remove only the app's photo copy and point from the current trip, leaving the system Photos library untouched. Back up the photo copy and point data before deletion.
- Bound each photo card's tap area to its visible frame so a clipped portrait photo cannot cover Add Photos.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `docs/tasks/task-20261011-2126-photo-timeline-controls.md`
- `docs/en/tasks/task-20261011-2126-photo-timeline-controls.md`

## Estimated Lines of Code

About 160 lines.

## Verification Focus

Use a portrait photo to check the Add Photos hit area; verify view switching, interval recalculation after deletion, persistence after relaunch, and that the original remains in the Photos library.
