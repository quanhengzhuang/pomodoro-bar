# WeReadShelf Reading Time and Grid Layout

## Goal

Show available per-book reading time from WeRead, remove misleading zero-second totals from the bookshelf, and visually align grid covers with their text.

## Changes

- Read per-book time in seconds from `book.readingTime`, as observed in gateway responses. Keep the current sync and on-demand lookup flow. When time is zero or missing, show the last reading date in the list and an unavailable message in the details. [Per-book API observation](https://github.com/MilkyWay-qt/weread-mcp#与官方-weread-skills-怎么选) · [Sample response](https://github.com/zhaohongxuan/obsidian-weread-plugin/blob/main/docs/weread-agent-api.md#bookgetprogress--阅读进度)
- Use narrower grid columns and tighter vertical spacing. Give the cover and text the same content width and left edge. Limit titles to two lines, place the author directly below short titles, and reveal the full title on hover. Keep the 40 pt covers in list view and the shelf picker.

## Affected Files

- `macOS/WeReadShelf/App/WeReadAPI.swift`, `LibraryStore.swift`, and `LibraryView.swift`
- `README.md` and `docs/en/README.md`
- Chinese and English task documents

## Estimated Lines of Code

About 70–120 changed lines of Swift.

## Data and Verification Focus

- Cache time for the current account and retain existing lists and reading dates when reading an older cache. Verify responses that include both duration fields, missing durations, older caches, refresh failures, and long titles.
- Build the standalone project and run the repository's `./scripts/build.sh`, then update `dist/WeReadShelf.app`.
