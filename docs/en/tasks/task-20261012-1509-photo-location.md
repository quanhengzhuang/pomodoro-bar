# Show Photo Locations and Distance Between Stops

## Goal

Show where a photo was taken in the timeline and point editor, and show the distance between adjacent photo locations beside their time interval.

## Changes

- Read GPS metadata from newly imported and existing in-app photo copies. When coordinates exist, try to resolve a readable city and district; show coordinates if lookup fails.
- Show the place in large and compact cards. Let people enter or correct it in the editor. Hide the location line when neither GPS nor a manual place is available.
- When adjacent points both have GPS coordinates, show their straight-line distance next to the time interval. Use meters below 1 km and kilometers otherwise. If either point lacks coordinates, show only the time interval.
- Save optional place data for each point. Keep older trips without these fields readable and leave photo files unchanged.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `docs/tasks/task-20261012-1509-photo-location.md`
- `docs/en/tasks/task-20261012-1509-photo-location.md`

## Estimated Lines of Code

About 150–220 lines.

## Verification Focus

Check new and existing photos with and without GPS, coordinate display after a failed place lookup, straight-line distance between stops, manual edits, and persistence after relaunch. Place lookup needs network access, and the photo picker may omit GPS metadata.
