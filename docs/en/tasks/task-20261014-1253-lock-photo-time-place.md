# Lock Photo Time and Place

## Goal

Show the photo's capture time and place without allowing edits in the editor.

## Changes

- Remove the time toggle, date picker, place field, and place refresh button.
- Show time and place as read-only details while retaining notes, photo framing, and deletion.
- Remove time and place from the point update API.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- This task in Chinese and English

## Estimated Lines of Code

About 40–60 lines.
