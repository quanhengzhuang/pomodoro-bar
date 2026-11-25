# Rename the iOS project to bookworm (书虫)

## Goal

Rename the iPhone project to `bookworm`. Display `bookworm` in English and `书虫` in Simplified Chinese.

## Changes

- Rename the iOS project directory, Xcode project, shared scheme, and app product to `bookworm`. Rename the widget extension to `bookwormWidgets`.
- Localize the app name on the Home Screen and in the widget gallery. Keep the Recent Reading and My Book List widgets available.
- Update the iPhone project path, build steps, and widget search name in both READMEs.

## Affected files

- `iOS/WeReadShelf/` moves to `iOS/bookworm/`. Changes cover the project settings, shared scheme, both `Info.plist` files, and new `InfoPlist.strings` resources.
- The iPhone app sections in `README.md` and `docs/en/README.md`.

## Estimated lines of code

About 50–100 lines of project configuration and localization resources.

## Data and verification

Preserve the app and extension bundle IDs, App Group, both widget kinds, deep links, and storage keys so existing API keys, book lists, and widgets keep working. Build for the iOS simulator, check the display names and identifiers of both products, and run `./scripts/build.sh`.
