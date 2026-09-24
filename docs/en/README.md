[中文](../../README.md) | [English](README.md)

<img src="../assets/icon.png" alt="Pomodoro icon" width="148">

# Pomodoro · Menu Bar Pomodoro Timer

A lightweight macOS menu bar Pomodoro timer.

## Download

[Download the latest version](https://github.com/quanhengzhuang/pomodoro-bar/releases/latest), unzip it, and open `Pomodoro.app`. Older releases may still contain `PomodoroBar.app`.

## Preview

<img src="../assets/screenshot-menu.png" alt="Pomodoro menu preview" width="35%">

## Features

- Use a free-running timer from `00:00`, or follow a Pomodoro rhythm with 25-minute focus and 5/15-minute breaks
- Control everything from the menu bar: start, pause, resume, extend, or end while keeping progress visible
- Press Space while the menu is open to start, pause, or resume instantly
- Set “Daily Guidance” as multiline plain text with automatic wrapping; the editor matches the menu's 520-point width, color, font, and wrapping, and the menu retains guidance from the most recent 30 calendar days
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
dist/Pomodoro.app
```

Build and run the latest version while exiting an older running instance:

```bash
./scripts/restart.sh
```

An unfinished timer in the old instance is discarded; saved records are unaffected.

## Reading and Maintaining the Source

If you are new to Swift, AppKit, SwiftUI, or Live Activities, start with the [source reading and maintenance guide](code-reading-guide.md). Every Swift source file and build script also includes beginner-oriented Chinese comments explaining file responsibilities, state transitions, data compatibility, and common maintenance cautions.

## iOS App and Dynamic Island

The iOS app project is located at:

```text
iOS/DailyGuidance/DailyGuidance.xcodeproj
```

Open the project in the full Xcode application, select the `PomodoroBar` target, choose your Apple Developer Team under Signing & Capabilities, and run it in a simulator or on an iPhone. The app requires iOS 16.1 or later.

The iOS app supports a count-up timer, 25-minute focus, 5/15-minute breaks, pause, resume, duration adjustments, notes, and recent records. Starting a timer creates a Live Activity that shows elapsed or remaining time on the Lock Screen and in the Dynamic Island on supported iPhones; End becomes the highlighted red action during an active session. On iOS 17 and later, the Lock Screen and expanded Dynamic Island can pause/resume, add five minutes to a countdown, or end the session directly (count-up sessions omit the extension action). iOS 16.1–16.x keeps the read-only presentation. Allow notifications and make sure Live Activities are enabled under Settings > Pomodoro Bar.

The quote button in the top-right corner opens Daily Guidance with Chinese dates such as “2026年9月17日 星期四”. You can edit and save today’s entry or any non-empty historical entry from the most recent 30 calendar days; edit mode shows only the selected date’s card for a focused workspace. Editing and display states share the same warm-amber italics, font size, line spacing, padding, and wrapping width. On first use, select `iCloud Drive/PomodoroBar/daily-guidance.json` in the system file picker; saving updates only the selected date and preserves all others. iOS timer records stay in the app's own sandbox and never overwrite or delete Mac data.

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
