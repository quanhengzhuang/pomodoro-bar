# Daily Guidance Editing and Timeline

## Goal

Allow the iOS app to edit today's Daily Guidance and browse the most recent 30 days in one vertically scrolling view, while matching the Mac editor to its display styling.

## Changes

- Show today's date on the Daily Guidance screen while retaining the warm-amber italic, multiline, wrapping style.
- Add an editing entry point for multiline updates to today's entry in the selected `daily-guidance.json`.
- Replace the drill-down history flow with a vertically scrolling date timeline that continuously displays non-empty entries from the most recent 30 calendar days in reverse chronological order.
- Preserve all other dates when saving, show a clear error when writing fails, and never delete history content.
- Give the Mac editor the same 520-point width, warm-amber color, italics, font size, padding, and wrapping width as the menu display.
- Update the Chinese and English READMEs.

## Affected Files

- `iOS/DailyGuidance/DailyGuidance/GuidanceStore.swift`
- `iOS/DailyGuidance/DailyGuidance/ContentView.swift`
- `Sources/main.swift`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260917-1429-daily-guidance-edit-timeline.md`
- `docs/en/tasks/task-20260917-1429-daily-guidance-edit-timeline.md`

## Estimated Code Changes

Approximately 250–350 lines of Swift and documentation updates.

## Data and Verification Notes

- Retain the existing date-to-plain-text JSON format and iCloud file authorization without migrating or clearing data.
- Verify multiline saving, reloading, date display, timeline ordering, and the 30-day filter.
- Verify matching colors, fonts, content widths, and wrapping positions between editing and display states on iOS and Mac.

## Actual Changes

- Replaced the iOS Daily Guidance drill-down with a dated timeline: today stays at the top and is editable, while other non-empty entries appear continuously in reverse chronological order for vertical scrolling.
- Reused one styled text component for iOS editing and display, keeping warm-amber italics, font size, line spacing, padding, and wrapping width identical; saving updates only today and preserves every other date.
- Expanded the Mac editor to the same 520-point width as the menu and reused the same color, font, italics, padding, and text content width.
- Updated the Chinese and English READMEs.

## Verification Results

- The iOS app Swift sources passed type checking against the iPhoneOS SDK.
- `./scripts/build.sh` succeeded with only the existing deprecated notification API warnings.
- `git diff --check` passed; the generic iPhone build remains limited at asset compilation because this machine has no iOS Simulator runtime.
