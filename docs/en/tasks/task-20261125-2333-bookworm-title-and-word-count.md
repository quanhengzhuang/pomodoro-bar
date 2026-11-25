# Bookworm page headings and word counts

## Goal

Enlarge the two shelf headings slightly and fill in word counts and reader counts.

## Changes

- Enlarge the leading-aligned My List and Recently Read page headings.
- Slightly increase tracking for list titles, authors, and metadata.
- Prefer the total from book details. When absent, look up the official chapter list and show a total only when the chapter counts can be combined reliably.
- Show the reader count next to the recommendation, matching the exact book ID. Put the date, duration, and word count on the next line and simplify the duration label.
- Open the WeRead reader from covers and book details from list text. Style the extra separator on the date line of shared images.
- Look up word counts previously cached as missing. Keep existing shelves, reading times, and recommendations readable.

## Affected files

- iOS Bookworm's LibraryView.swift and BookListShare.swift.
- Shared WeReadAPI.swift and LibraryStore.swift.

## Estimated code size

About 100–160 lines of Swift.

## Verification

Verify the direct total, chapter fallback, exact book matching for reader counts, missing data, and older caches. Build and install the iPhone app.
