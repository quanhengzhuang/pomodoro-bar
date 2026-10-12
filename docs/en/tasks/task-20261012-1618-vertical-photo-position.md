# Adjust Photo Position Vertically Only

## Goal

Make photo positioning a vertical drag interaction and remove the awkward horizontal sliders.

## Changes

- Make the editor preview respond only to vertical dragging and remove both horizontal and vertical position sliders.
- Preserve existing horizontal position data; dragging changes only vertical position, and “Reset Vertical Position” resets only vertical position.
- Change the hint to “Drag the photo up or down to adjust its position.”

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261012-1618-vertical-photo-position.md`
- `docs/en/tasks/task-20261012-1618-vertical-photo-position.md`

## Estimated Lines of Code

About 15–25 lines.
