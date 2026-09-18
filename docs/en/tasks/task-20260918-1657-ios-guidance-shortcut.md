# iOS Daily Guidance Shortcut

## Goal

Separate viewing Daily Guidance from configuring its data source, while keeping the viewing entry easy to tap without dominating the home screen.

## Changes

- Keep the top-right icon position and use it to configure the guidance data file.
- Add a compact Daily Guidance button above Recent Records that remains visible when there are no records.
- Reuse the existing file selection, refresh, and sheet behavior.

## Affected Files

- `iOS/DailyGuidance/DailyGuidance/ContentView.swift`

## Estimated Lines of Code

About 30 lines.
