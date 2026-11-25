# Adjust the book list tab and editing gesture

## Goal

Place My Book List first and enter drag editing by pressing and holding a book.

## Changes

- Move My Book List to the leftmost tab and select it on ordinary launch.
- Remove the Reorder button. Touch and hold a book in the list or grid to enter editing, and tap Done to exit. In the grid, the cover's corner menu provides access to book removal while editing.
- Outline and lightly tint the destination tile when a book is dragged over a valid grid position.

## Affected files

- `iOS/bookworm/App/LibraryView.swift`

## Estimated lines of code

About 45–85 lines of Swift.

## Verification

Check tab order, touch-and-hold activation, cover taps, target highlighting, drag persistence, and leaving edit mode.
