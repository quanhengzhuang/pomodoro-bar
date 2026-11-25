# Automatic reading times in Bookworm lists

## Goal

Automatically load total reading times for all books in My List and Recently Read, and standardize cover dimensions and text size in the iPhone list layout.

## Changes

- Look up reading times book by book across both lists, reusing cached results and active requests. Pull to refresh to look up durations again. Accept both per-book duration fields.
- Use uniform list cover dimensions and match the title size to the author, duration, and date.

## Affected files

- `macOS/WeReadShelf/App/LibraryStore.swift`, `macOS/WeReadShelf/App/WeReadAPI.swift`
- `iOS/bookworm/App/LibraryView.swift`

## Estimated code size

About 70–110 lines of Swift.

## Verification

Verify books beyond the first five and deduplication across both lists. Check covers with different proportions and list typography. Build and install the iPhone app.
