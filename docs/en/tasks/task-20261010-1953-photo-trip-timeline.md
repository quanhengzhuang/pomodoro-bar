# Photo Trip Timeline App

## Goal

Add a standalone iPhone app that arranges trip photos by capture time, showing when each stop happened and the elapsed time between consecutive stops.

## Changes

- Create a separate SwiftUI iOS app and Xcode project, with photos organized by trip.
- Import multiple photos at once, read capture time when available, sort by time, and allow missing or incorrect times to be entered or edited.
- Make each photo a timeline point with a place or event note; show the interval since the previous point.
- Store trips, photo copies, times, and notes locally so they remain available for viewing and editing after relaunch.

## Affected Files

- `iOS/PhotoTimeline/PhotoTimeline.xcodeproj/`
- `iOS/PhotoTimeline/PhotoTimeline/` (app, timeline UI, photo import, and local storage)
- `docs/tasks/task-20261010-1953-photo-trip-timeline.md`
- `docs/en/tasks/task-20261010-1953-photo-trip-timeline.md`
- `README.md` and `docs/en/README.md`

## Estimated Lines of Code

About 600 lines.

## Data and Verification Focus

- Import must leave the original Photos library unchanged; verify missing times, overnight trips, and ordering and intervals for equal timestamps.
