# Share the complete bookworm list as images

## Goal

Generate and share an image of every book in My Book List with one action, and refine the widget title and cover treatment.

## Changes

- Render the entire list or grid in its current order. Split very tall exports at row boundaries. Include the book title and a placeholder if a cover is unavailable.
- Show progress while generating, then present the system share sheet to save or share the images.
- Specify a heavier Chinese widget heading and add a thin gray outline and a subtle tonal gradient to each cover.

## Affected files

- `iOS/bookworm/App/LibraryView.swift`, a new image rendering file, and its Xcode source reference
- `macOS/WeReadShelf/Widget/ReadingWidgets.swift`

## Estimated lines of code

About 190–300 lines of Swift and project settings.

## Verification

Check offscreen books, order preservation, splitting long lists, and sharing in both layouts. Review the widget heading weight and cover edges. Build and install the iPhone update in place, and run `./scripts/build.sh`.
