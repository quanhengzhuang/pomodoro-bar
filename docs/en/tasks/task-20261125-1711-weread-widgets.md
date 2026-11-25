# WeRead Desktop Widgets

## Goal

Create a standalone macOS 14+ app in `macOS/WeRead/` for viewing recent WeRead reading and one custom book list. Both lists can be added to the Mac desktop independently.

## Changes

- Link to the official WeRead API key page from Settings. Let users enter and replace the key, and store it in the macOS Keychain.
- Fetch ebooks from the user's shelf through the official Skill's `/shelf/sync` endpoint and show them in descending order of last reading time. Sync on app launch and provide a manual refresh. [Official shelf API](https://github.com/Tencent/WeChatReading/blob/main/skills/shelf.md)
- Let users add ebooks from their shelf to one local custom list, remove them, and reorder them.
- Offer two WidgetKit widgets, Recent Reading and Custom Book List, in the Mac's Edit Widgets gallery. Both can be added at the same time. They show the last synced or saved lists and open the corresponding list in the app when clicked. [Apple's guide to adding widgets](https://support.apple.com/guide/mac-help/add-and-customize-widgets-mchl52be5da5/mac)

## Affected Files

- `macOS/WeRead/` (standalone Xcode project, app, widget extension, and shared data model)
- `README.md` and `docs/en/README.md` (build, signing setup, and usage)
- Chinese and English task documents

## Estimated Lines of Code

About 500–700 lines of Swift, plus Xcode project configuration.

## Verification Focus

- Verify key validation, recent reading order, custom list persistence, and access to the last sync while offline.
- Build the new Xcode project and run the repository's `./scripts/build.sh`. With a signed build that has App Groups configured, add both widgets to the desktop and verify that list updates appear.
