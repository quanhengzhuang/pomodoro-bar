# Refresh Specific Places for Existing Photos

## Goal

Show a more specific place for previously imported photos when map data provides a venue name.

## Changes

- Look up existing geotagged photos again; replace a place only when its old value matches the previously generated city and district name.
- Store a lookup version to avoid repeated requests while preserving old data and custom names.
- Correct the import message for photos without capture times.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- This task in Chinese and English

## Estimated Lines of Code

About 35–55 lines.
