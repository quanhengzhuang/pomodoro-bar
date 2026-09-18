# Focused iOS Guidance Editing and Historical Edits

## Goal

Hide unrelated content while editing today's guidance, allow editing and saving historical guidance entries, and display dates as “September 17, 2026 Thursday” in the Chinese UI format equivalent to “2026年9月17日 星期四”.

## Changes

- Focus the current editing area by hiding the history list and non-editing actions while today's guidance is being edited.
- Allow historical entries to enter edit mode, save, or cancel without changing other JSON dates.
- Use one Chinese date presentation for today's and historical guidance cards.

## Affected Files

- `iOS/DailyGuidance/DailyGuidance/ContentView.swift`
- `iOS/DailyGuidance/DailyGuidance/GuidanceStore.swift`
- `docs/tasks/task-20260918-1113-ios-guidance-edit-focus.md`

## Estimated Code Changes

Approximately 100–160 lines of Swift plus a small task-document update.

## Compatibility and Verification Focus

- Preserve the existing `daily-guidance.json` date keys and overall format.
- Save historical edits only under their corresponding dates without overwriting other entries.
- Verify save/cancel flows, unwritable-file errors, and the Chinese date presentation for today and history.

## Verification Results

- Both today and historical dates can enter the focused editing state; saving or cancelling returns to the complete timeline.
- Saving updates one entry by its original `yyyy-MM-dd` key while preserving the JSON shape and every other date.
- Dates now consistently use the Chinese `yyyy年M月d日 EEEE` format. Source type checking and a signed build with the iOS 16.1 deployment target passed.
