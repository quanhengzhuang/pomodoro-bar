# Adjust Photo Framing in Timeline Cards

## Goal

Let people position a photo within its timeline card so the subject stays visible.

## Changes

- Add a draggable card preview and horizontal and vertical position sliders to the point editor, with a reset to center action. Apply the saved position in both large and compact modes.
- Limit movement based on the image and card sizes so the crop never reveals empty space. Leave the original photo unchanged.
- Save a normalized framing position for each point. Existing trips without this value continue to show centered photos.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `docs/tasks/task-20261012-1507-photo-card-framing.md`
- `docs/en/tasks/task-20261012-1507-photo-card-framing.md`

## Estimated Lines of Code

About 120–170 lines.

## Verification Focus

Check portrait and landscape crops in both modes, drag limits, position persistence after relaunch, and loading of existing trips.
