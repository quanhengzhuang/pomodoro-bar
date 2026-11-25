# Make grid drop positions explicit in bookworm

## Goal

Show whether a dragged book will go before or after its target and make the resulting order match the indicator.

## Changes

- Replace the full-tile blue highlight with an insertion line. The left half drops before the target book and the right half drops after it. In the single-column accessibility layout, use the upper and lower halves for before and after.
- Save the order shown by the insertion line regardless of drag direction. Clear the line when a drag is canceled.

## Affected files

- `iOS/bookworm/App/LibraryView.swift`

## Estimated lines of code

About 45–90 lines of SwiftUI changes.

## Verification

Start drags on both sides of a target book and verify drops before and after it. Check moves across rows, leaving edit mode, and order preservation after relaunch. Rebuild and install the iOS device build in place, and run `./scripts/build.sh`.
