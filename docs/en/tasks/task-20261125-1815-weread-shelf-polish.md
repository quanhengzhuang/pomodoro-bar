# WeReadShelf Book List and Icon Polish

## Goal

Refine grid spacing and book list controls, and add a blue book-stack icon inspired by the reference.

## Changes

- Increase horizontal and vertical grid spacing by 4 pt. The cover and text continue to share the 110 pt content width.
- Remove the reading data popover. Clicking the clock requests or refreshes the book's total reading time in its existing position on the card or list row.
- Rename Custom Book List to My Book List in the app and desktop widget. Before removing a book in either layout, show its title with Cancel and Remove actions. Update the list on confirmation.
- Use the selected blue-and-white book-stack artwork. Preserve its composition and export the required macOS app icon sizes.

## Affected Files

- `macOS/WeReadShelf/App/LibraryView.swift` and `macOS/WeReadShelf/Shared/ReadingModels.swift`
- `macOS/WeReadShelf/App/Assets.xcassets/AppIcon.appiconset/`
- `README.md`, `docs/en/README.md`, and both task documents

## Estimated Lines of Code

About 50–90 changed lines of Swift, plus the icon images.

## Data and Verification Focus

- Reuse existing book list data, widget identifiers, and deep links. Verify removal and cancellation, per-book refresh, and icon packaging. Build the repository and update `dist/WeReadShelf.app`.
