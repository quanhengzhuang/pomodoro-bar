# Place Display Options

## Goal

Let the timeline show city plus venue, city plus district, or no place.

## Changes

- Save city, district, and venue returned by geocoding, and refresh existing geotagged photos once.
- Add a place display setting to the trip menu for both timeline sizes.
- Default to city plus venue, falling back to city plus district when no venue is available.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- This task in Chinese and English

## Estimated Lines of Code

About 70–100 lines.
