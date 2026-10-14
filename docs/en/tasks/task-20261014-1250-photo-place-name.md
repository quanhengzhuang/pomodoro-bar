# Show Specific Photo Place Names

## Goal

Show a named venue such as a shopping mall when a photo has GPS data.

## Changes

- Prefer a map-provided point of interest name, falling back to the city and district.
- Add a place refresh action in the photo editor for existing imports without automatically replacing manually entered names.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- This task in Chinese and English

## Estimated Lines of Code

About 30–50 lines.
