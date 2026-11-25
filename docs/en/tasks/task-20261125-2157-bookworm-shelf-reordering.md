# Refine bookworm grid spacing and book list ordering

## Goal

Make grid titles more compact and horizontal gaps consistent. Open My Book List by default and let readers drag books to reorder them.

## Changes

- Reduce grid titles from about 13 pt to about 12 pt, with Dynamic Type scaling. Use 14 pt for both side margins and column gaps, with four books per row at standard text sizes.
- Open My Book List at ordinary launch. Open the corresponding list when launched from a widget.
- Add a Reorder action to My Book List. In reorder mode, drag the list's reorder handles or move grid cards across columns and rows. Insert the dragged book at its destination and shift the intervening books. Keep the existing menu actions for moving one book up or down.

## Affected files

- `iOS/bookworm/App/LibraryView.swift`
- The book list order persistence shared with iOS in `macOS/WeReadShelf/App/LibraryStore.swift`, as needed

## Estimated lines of code

About 80–150 lines of Swift.

## Data and verification

Save the new order and update the widgets when a book is dropped. Keep the original order if a drag is canceled. Verify dragging in both directions in both layouts, moves across grid rows, persistence after relaunch, the default tab, widget links, and grid spacing. Rebuild the iOS simulator and device products, and run `./scripts/build.sh`.
