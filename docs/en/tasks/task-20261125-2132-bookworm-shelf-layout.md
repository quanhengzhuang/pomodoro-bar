# Refine the bookworm shelf layouts on iPhone

## Goal

Make the Recent Reading and My Book List grids more compact, and align the covers, text, and actions in list view.

## Changes

- Fit four books across the grid at standard text sizes. Use smaller, square-cornered covers and a single medium-weight title line roughly 13–14 pt, following the reference's proportions. Truncate long titles at the end. Keep the single-column layout for accessibility text sizes.
- Limit list titles to one line. Set the author, total reading time, and last-read date to the current reading-time text size. Match the cover height to the visible text block, including all four lines when available. Center the ellipsis button vertically within the row.
- Remove the standalone clock button and put manual reading-time refresh in the action menu. Touch and hold a grid cell or a Recent Reading list row to open it, or tap the ellipsis in My Book List. The menu also keeps the existing list reordering and removal confirmation. Tapping a cover opens WeRead.

## Affected files

- `iOS/bookworm/App/LibraryView.swift`

## Estimated lines of code

About 60–110 lines of SwiftUI changes.

## Verification

Check both layouts on an iPhone simulator with long titles, complete four-line rows, and missing reading data. Verify cover links, context menus, and removal confirmation. Rebuild the iOS simulator and device products, and run `./scripts/build.sh`.
