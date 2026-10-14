# Inline Trip Editing and Empty Trip Entry

## Goal

Allow inline title editing and direct photo removal in the detail view, and open an empty trip titled “一段旅程” from the home plus button.

## Changes

- Replace the title edit sheet with an inline editor and save action.
- Show a delete button for every photo in both large and compact timelines while editing, with deletion confirmation.
- Make the home plus button create and open an empty trip; import photos only after tapping Save in the photo picker.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `docs/tasks/task-20261014-1925-inline-trip-editing.md`
- `docs/en/tasks/task-20261014-1925-inline-trip-editing.md`

## Estimated Lines of Code

About 130–180 lines.
