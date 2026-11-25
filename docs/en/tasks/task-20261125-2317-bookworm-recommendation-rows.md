# Bookworm recommendations and list rows

## Goal

Use spacing to separate rows on the light gray shelf, show WeRead recommendation values and word counts, and combine reading dates and durations.

## Changes

- Use the reference shelf color, `#F4F5F7`, on iPhone shelves and widgets in light appearance. Keep the system color in dark appearance.
- Drop list separators and use spacing to distinguish rows. Enlarge covers to one consistent size. Show recommendation and word count together, followed by the reading date and duration on one line. Use the same details in shared list images.
- Fetch and cache recommendation values and word counts from the WeRead book information endpoint. Keep existing shelf caches readable.

## Affected files

- `iOS/bookworm/App/LibraryView.swift`
- `macOS/WeReadShelf/App/LibraryStore.swift`, `macOS/WeReadShelf/App/WeReadAPI.swift`
- `macOS/WeReadShelf/Shared/ReadingModels.swift`, `macOS/WeReadShelf/Widget/ReadingWidgets.swift`

## Estimated code size

About 85–140 lines of Swift.

## Verification

Check background pixels, list layout, recommendation conversion and missing fields. Build and install the iPhone app.
