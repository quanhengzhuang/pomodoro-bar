# WeReadShelf Icon, Library Views, and Reading Stats

## Goal

Rename the standalone Mac project to WeReadShelf, add an app icon, and make it easier to browse both lists, see reading stats for each book, and resume reading from its cover.

## Changes

- Rename the directory, Xcode project, scheme, build product, and app display name to WeReadShelf. Create an original bookshelf icon and add it to the app's macOS assets.
- Offer independent list and grid layouts for Recent Reading and Custom Book List in the app. Remember each layout choice and support adding, removing, and reordering custom books in either layout.
- Open the WeRead reader when a cover is clicked, with the official book detail link as a fallback. Remove the existing arrow link. [WeRead link conventions](https://github.com/Tencent/WeChatReading/blob/main/skills/SKILL.md)
- Show total reading time, progress, and the last reading date in both layouts. Show the completion date when available for finished books. Fetch stats for the five most recently read ebooks after sync, load other books on demand, and make saved stats available offline. [Reading progress API](https://github.com/Tencent/WeChatReading/blob/main/skills/book.md) · [Official reading overview](https://github.com/Tencent/WeChatReading/blob/main/skills/profile.md)
- Sort the shelf picker from most to least recently read, with unread books last. Use the same ordering for search results.

## Affected Files

- `macOS/WeRead/` → `macOS/WeReadShelf/` (project, app, icon assets, and reading stats cache)
- `README.md` and `docs/en/README.md` (new path and usage)
- Chinese and English task documents

## Estimated Lines of Code

About 280–420 changed lines of Swift, plus project configuration and icon assets.

## Data and Verification Focus

- Reuse the bundle IDs, App Group, Keychain item, local storage path, and both widget identifiers. Read existing book lists and store reading stats for the current account.
- Verify reading time units, missing data, existing caches, layout selection, shelf picker sorting, and cover links. Check the packaged icon, build the standalone project, and run the repository's `./scripts/build.sh`.
