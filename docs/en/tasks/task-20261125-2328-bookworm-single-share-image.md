# One image for the complete Bookworm list

## Goal

Share the complete shelf in one PNG from either the list or grid.

## Changes

- Render rows in bounded sections and write them to a single PNG. Include one heading and total book count.
- Share one file and clean up temporary files when generation is canceled or fails.
- Use smaller titles in the app grid, close to the size of the shared image when viewed at phone width.

## Affected files

- iOS Bookworm's BookListShare.swift, LibraryView.swift, PNG writer, and Xcode references.

## Estimated code size

About 180–250 lines of Swift and project configuration.

## Verification

Use shelves that exceed the old page height to check both layouts, book order, PNG decoding, and the share sheet. Build and install the iPhone app.
