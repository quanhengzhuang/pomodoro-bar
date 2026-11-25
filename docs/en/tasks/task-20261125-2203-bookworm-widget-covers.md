# Book covers and reading links in bookworm iPhone widgets

## Goal

Make book covers the focus of the Recent Reading and My Book List Home Screen widgets. Tapping a cover opens the corresponding destination in WeRead.

## Changes

- Show up to four square-cornered covers with single-line titles in a medium widget. Focus the small widget on the first book. Use bookworm's header icons and colors, with a titled placeholder when artwork is unavailable.
- Cache thumbnails in the iOS App Group. Fetch the current covers after a list update and reload the widgets when the thumbnails are ready. Reuse cached artwork offline.
- iOS delivers the cover tap to bookworm, which immediately tries to open WeRead. Prefer the supplied reader link and use the supplied detail link or website when appropriate. Empty areas and books without links can open their list in bookworm.

## Affected files

- `iOS/bookworm/App/LibraryView.swift`
- `macOS/WeReadShelf/Widget/ReadingWidgets.swift`
- `macOS/WeReadShelf/Shared/ReadingModels.swift` and `macOS/WeReadShelf/Shared/WidgetSnapshotStore.swift`
- `macOS/WeReadShelf/App/LibraryStore.swift`

## Estimated lines of code

About 160–260 lines of Swift.

## Data and verification

Keep the existing widget identifiers, App Group, and list data. Use fixture covers to check both sizes, both lists, and book-specific links. Build and install the iPhone update in place. Run `./scripts/build.sh`.
