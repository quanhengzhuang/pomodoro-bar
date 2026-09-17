# iOS Daily Guidance History

## Goal

Allow the iOS app to display Daily Guidance from the most recent 30 calendar days.

## Changes

- Add a history entry point to the Daily Guidance screen and list non-empty entries from the most recent 30 calendar days in reverse chronological order.
- Show the date and weekday in the list; retain the warm-amber italic plain-text style in detail views, with multiline wrapping and scrolling.
- Continue reading the existing `daily-guidance.json` without changing its format, path, or history.
- Update the Chinese and English READMEs.

## Affected Files

- `iOS/DailyGuidance/DailyGuidance/GuidanceStore.swift`
- `iOS/DailyGuidance/DailyGuidance/ContentView.swift`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260917-1240-ios-daily-guidance-history.md`
- `docs/en/tasks/task-20260917-1240-ios-daily-guidance-history.md`

## Estimated Code Changes

Approximately 100–160 lines of Swift and documentation updates.

## Verification Focus

- Verify that today and earlier test entries appear in reverse chronological order, while empty and older-than-30-day entries are excluded.
- Preserve the existing clear states for expired permissions, missing files, and invalid JSON.
- Pass iOS source checks, the macOS build, and the pre-commit status check.

## Actual Changes

- Added a calendar entry point to the Daily Guidance screen, listing non-empty entries from the most recent 30 calendar days in reverse chronological order.
- The history list shows each date and weekday; details retain the warm-amber italic plain-text view with multiline wrapping, scrolling, and text selection.
- Continued to read the existing `daily-guidance.json` without changing its format, path, or stored content.
- Updated the Chinese and English READMEs with the iOS history flow.

## Verification Results

- The iOS app Swift sources passed type checking against the iPhoneOS SDK.
- `./scripts/build.sh` succeeded with only the existing deprecated notification API warnings, and `git diff --check` passed.
- A generic iPhone build reached Swift compilation; final packaging stopped at asset compilation because this machine has no available iOS Simulator runtime.
