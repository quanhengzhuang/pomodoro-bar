# Select Photos by Date

## Goal

Let people choose a date when tapping Add Photos, then browse and import photos from that day.

## Changes

- Add a date based photo browser showing photos from the selected day with multi selection.
- Keep the system photo picker as a Browse All Photos option and as a fallback when library access is limited.
- Import selected assets into the existing trip using the same original image, capture time, location, and thumbnail storage.
- Add a photo library usage description.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `iOS/PhotoTimeline/PhotoTimeline.xcodeproj/project.pbxproj`
- `docs/tasks/task-20261014-1241-select-photos-by-date.md`
- `docs/en/tasks/task-20261014-1241-select-photos-by-date.md`

## Estimated Lines of Code

About 170–230 lines.
