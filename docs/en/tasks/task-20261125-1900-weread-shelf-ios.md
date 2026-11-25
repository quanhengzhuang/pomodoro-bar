# WeReadShelf iPhone App and Home Screen Widgets

## Goal

Create a native SwiftUI project in `iOS/WeReadShelf/` for iOS 17 or later. Show both WeRead lists on iPhone and let users add each list to the Home Screen.

## Changes

- Reuse the WeReadShelf name and blue book-stack icon. Configure the WeRead API key in the app and save it in the iOS Keychain. Sync the shelf on launch and when the user pulls to refresh.
- Offer list and grid layouts for Recent Reading and My Book List. Show the last reading date and available total reading time, and open WeRead when a cover is tapped. Pick books in last-read order, reorder the list, and confirm before removing a book.
- Provide two small and medium WidgetKit Home Screen widgets for Recent Reading and My Book List. Update the local widget snapshot after a sync or list edit, and open the corresponding list when tapped. [Apple's Home Screen widget guide](https://support.apple.com/en-us/118610)
- Share the WeRead API client, list models, storage, and widget logic across iOS and macOS. Keep the iPhone lists and cache on the device.

## Affected Files

- `iOS/WeReadShelf/` (Xcode project, iPhone views, icon, and signing configuration)
- The iOS project references existing platform-independent Swift sources in `macOS/WeReadShelf/`
- `README.md`, `docs/en/README.md`, and both task documents

## Estimated Lines of Code

About 300–500 new or changed lines of Swift, plus Xcode project and resource configuration.

## Data and Verification Focus

- Use one App Group for the iOS app and extension to exchange the data displayed in the lists. Store the API key in the app's own Keychain scope. [Apple App Groups documentation](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- Verify the iOS Simulator build, list edits, widget snapshots, and tap routing. Build the macOS project and run `./scripts/build.sh`. Testing on an iPhone requires configuring both targets with the same Apple Developer Team that can use App Groups.
