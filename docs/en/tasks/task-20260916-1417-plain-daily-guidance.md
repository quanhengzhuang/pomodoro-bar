# Simplify Daily Guidance Display

## Goal

Render Daily Guidance as plain text and ensure content with many lines remains fully visible.

## Changes

- Remove unordered-list, ordered-list, and bold parsing while retaining manual line breaks and automatic wrapping for long lines.
- Display Markdown markers as ordinary text without changing the existing `daily-guidance.json` format or content.
- Render the entire block in warm amber italics without supporting per-content rich-text formatting.
- Increase the menu content width from 320 points to 520 points so each line shows more text with less unnecessary wrapping.
- Size the menu content area from the text layout's actual height so multiline content is not clipped.
- Remove rich-text formatting guidance from the editor dialog.
- Update the Chinese and English READMEs.

## Affected Files

- `Sources/main.swift`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260916-1417-plain-daily-guidance.md`
- `docs/en/tasks/task-20260916-1417-plain-daily-guidance.md`

## Estimated Code Changes

Delete approximately 80–100 lines and add or adjust around 30–50 lines of code plus minor documentation updates.

## Actual Changes

- Removed list, numbering, and bold parsing so existing formatting markers now appear as ordinary text.
- Changed Daily Guidance to a 520-point-wide, uniformly italic warm-amber plain-text block with only manual line breaks and automatic wrapping.
- Sized the menu view using the text layout manager's actual rendered height to prevent multiline clipping.
- Removed rich-text formatting instructions from the editor and both READMEs.
- Kept the `daily-guidance.json` path, structure, and existing content unchanged.

## Verification

- `./scripts/build.sh` completed successfully with only the existing notification API deprecation warnings.
- `git diff --check` passed, and the list and bold parsing methods are no longer present in the source.
