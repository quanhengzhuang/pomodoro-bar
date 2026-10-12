# Revert Large Photo Timeline Layout

## Goal

Undo the card-width adjustment in `8a54600` and restore the related large-photo timeline styling from before `7f36b91` (`88269a4`).

## Changes

- Restore the date circle, left timeline column, card spacing, and photo display aspect ratio to the `88269a4` layout.
- Restore the time and place font sizes and time text scaling behavior in cards to the `88269a4` styling.
- Keep the later year dividers, elapsed time and distance, colors, and other features, while aligning the timeline rail with the restored layout.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261012-1926-revert-photo-timeline-layout.md`
- `docs/en/tasks/task-20261012-1926-revert-photo-timeline-layout.md`

## Estimated Lines of Code

About 20–40 lines.
