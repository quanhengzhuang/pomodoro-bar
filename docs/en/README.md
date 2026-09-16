[中文](../../README.md) | [English](README.md)

<img src="../assets/icon.png" alt="Pomodoro Bar icon" width="148">

# Pomodoro Bar · Menu Bar Pomodoro Timer

A lightweight macOS menu bar Pomodoro timer.

## Download

[Download the latest version](https://github.com/quanhengzhuang/pomodoro-bar/releases/latest/download/PomodoroBar.zip), unzip it, and open `PomodoroBar.app`.

## Preview

<img src="../assets/screenshot-menu.png" alt="Pomodoro Bar menu preview" width="35%">

## Features

- Use a free-running timer from `00:00`, or follow a Pomodoro rhythm with 25-minute focus and 5/15-minute breaks
- Control everything from the menu bar: start, pause, resume, extend, or end while keeping progress visible
- Press Space while the menu is open to start, pause, or resume instantly
- Set “Daily Guidance” as multiline plain text with automatic wrapping, then review it whenever the menu is open
- Add a note to the current session and keep it with the record
- Receive a macOS notification when a focus or break session finishes
- Review today’s sessions with their time range, active duration, and notes
- No app account required—records and daily guidance prefer iCloud Drive and automatically fall back to local storage when iCloud is unavailable

## Build

```bash
./scripts/build.sh
```

The built application is written to:

```text
dist/PomodoroBar.app
```

Build and run the latest version while exiting an older running instance:

```bash
./scripts/restart.sh
```

An unfinished timer in the old instance is discarded; saved records are unaffected.

## iOS Daily Guidance

The iOS viewer project is located at:

```text
iOS/DailyGuidance/DailyGuidance.xcodeproj
```

Open the project in the full Xcode application, select the `DailyGuidance` target, choose your Apple Developer Team under Signing & Capabilities, and run it in a simulator or on an iPhone.

On first launch, use the system file picker to open `iCloud Drive/PomodoroBar/daily-guidance.json`. The app remembers access and automatically reads today's guidance on later launches; the toolbar can refresh or select a different file. The iOS app is read-only and does not modify existing data.

## Record Format

```json
[
  {
    "date" : "2026-07-28",
    "startedAt" : "2026-07-28 15:49:45",
    "endedAt" : "2026-07-28 16:14:45",
    "durationSeconds" : 1500,
    "durationMinutes" : 25,
    "type" : "focus",
    "note" : "Weekly report"
  }
]
```

Supported `type` values:

- `focus`
- `short_break`
- `long_break`
- `count_up`

## Data Location

`records.json` and `daily-guidance.json` are stored by default in:

```text
~/Library/Mobile Documents/com~apple~CloudDocs/PomodoroBar/
```

When iCloud Drive is unavailable or unwritable, the app falls back to:

```text
~/.pomodoro-status-bar/
```

Existing local records are deduplicated and merged with iCloud records without deleting the original local file. `daily-guidance.json` stores the plain-text Daily Guidance content by date.
