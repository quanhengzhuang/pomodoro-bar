# Daily Guidance

## Goal

Allow users to set and edit multiline guidance for the current day and display it clearly in the menu.

## Changes

- Name the feature “Daily Guidance”; show “Set Daily Guidance...” when empty, and show the content plus “Edit Daily Guidance...” once set.
- Use a multiline text editor and clear today's content when an empty value is saved.
- Support lightweight Markdown for unordered lists, ordered lists, and `**bold**`; keep list indentation while wrapping long content.
- Store the original Markdown text in `daily-guidance.json`; do not support nested lists, headings, links, or images.
- Store content by date in a readable `daily-guidance.json`; the menu reads only today's content without deleting data from previous dates.
- Store both `records.json` and `daily-guidance.json` in `~/Library/Mobile Documents/com~apple~CloudDocs/PomodoroBar/` by default.
- On first use, deduplicate and merge existing local records with iCloud records while keeping the original files under `~/.pomodoro-status-bar/` intact.
- Fall back to `~/.pomodoro-status-bar/` when iCloud Drive is unavailable or unwritable, then merge back into iCloud when it becomes available again.
- Display the content near the top of the menu with a constrained width, preserving manual line breaks and wrapping long text automatically.
- Add the feature to the Chinese and English READMEs.

## Affected Files

- `Sources/main.swift`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260916-1338-daily-guidance.md`
- `docs/en/tasks/task-20260916-1338-daily-guidance.md`

## Estimated Code Changes

Approximately 240–320 lines of code plus minor documentation updates.

## Actual Changes

- Added Daily Guidance near the top of the menu with multiline editing, automatic wrapping, set, edit, and clear behavior.
- Added lightweight Markdown rendering for unordered lists, ordered lists, and `**bold**`, including hanging indentation for wrapped list items.
- Made both `records.json` and `daily-guidance.json` prefer the shared `PomodoroBar` directory in iCloud Drive.
- Deduplicate and merge local and iCloud records while retaining the original local file; fall back locally when iCloud is unavailable or unreadable without overwriting an unreadable cloud file.
- Refresh cloud data whenever the menu opens and merge newer fallback files back into iCloud.
- Updated both READMEs with the data locations, fallback behavior, and Daily Guidance format.

## Verification

- `./scripts/build.sh` completed successfully with only the existing notification API deprecation warnings.
- `git diff --check` passed, with no references to earlier feature names or the old storage property remaining in source or documentation.
