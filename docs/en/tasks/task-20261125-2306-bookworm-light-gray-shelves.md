# Light gray Bookworm shelves and widgets

## Goal

Make white covers easier to distinguish in the iPhone library and widgets.

## Changes

- Use an appearance-aware background in both shelf tabs and layouts, with light gray in light mode.
- Use the same color in both iOS widgets. Remove the cover outlines and the accent strip on placeholders. Keep the rounded corners and subtle cover gradient.

## Affected files

- `iOS/bookworm/App/LibraryView.swift`
- iOS branch of `macOS/WeReadShelf/Widget/ReadingWidgets.swift`

## Estimated code size

About 15–25 lines of Swift.

## Verification

Check contrast with white covers, verify the widget styling, and install the updated iPhone app.
