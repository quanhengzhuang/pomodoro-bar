# Reference System Photos

## Goal

Store references to newly added library photos, and let users remove and re-add older copies.

## Changes

- Save the library identifier and metadata for new photos without copying originals or thumbnails.
- Load photos from the library, showing a placeholder when unavailable.
- Leave old copies in place and provide a per-trip removal action that backs up first and clears image copies after completion.
- Deleting a referenced photo removes only the app record, not the system library photo.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `iOS/PhotoTimeline/PhotoTimeline.xcodeproj/project.pbxproj`
- This task in Chinese and English

## Estimated Lines of Code

About 90–140 lines.
