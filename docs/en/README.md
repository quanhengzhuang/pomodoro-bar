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
- Set “Daily Guidance” as multiline plain text with automatic wrapping; the editor matches the menu's 520-point width, color, font, and wrapping, and the menu retains guidance from the most recent 30 calendar days
- Add a note to the current session and keep it with the record
- Receive a macOS notification when a focus or break session finishes
- Review today’s sessions with their time range, active duration, and notes
- No app account required—completed sessions and Daily Guidance sync between Mac and iPhone through the user's CloudKit private database, while readable JSON copies remain on-device

## Build

```bash
./scripts/build.sh
```

The ordinary script build uses ad-hoc signing and can run offline, but it cannot access CloudKit. To test Mac cloud sync, first prepare a development provisioning profile that includes `iCloud.local.codex.PomodoroBar`, then run:

```bash
POMODORO_CODESIGN_IDENTITY="Apple Development: Your Name (TEAM ID)" \
POMODORO_PROVISIONING_PROFILE="/absolute/path/to/profile.provisionprofile" \
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

## Reading and Maintaining the Source

If you are new to Swift, AppKit, SwiftUI, or Live Activities, start with the [source reading and maintenance guide](code-reading-guide.md). Every Swift source file and build script also includes beginner-oriented Chinese comments explaining file responsibilities, state transitions, data compatibility, and common maintenance cautions.

## iOS App and Dynamic Island

The iOS app project is located at:

```text
iOS/DailyGuidance/DailyGuidance.xcodeproj
```

Open the project in the full Xcode application, select the `PomodoroBar` target, choose an Apple Developer Team with iCloud access under Signing & Capabilities, and confirm the container is `iCloud.local.codex.PomodoroBar`. You can then run it in a simulator or on an iPhone. The app requires iOS 16.1 or later. See [CloudKit Setup and Recovery](cloudkit-setup.md) for first-time setup and Production schema deployment.

The iOS app supports a count-up timer, 25-minute focus, 5/15-minute breaks, pause, resume, duration adjustments, notes, and recent records. Starting a timer creates a Live Activity that shows elapsed or remaining time on the Lock Screen and in the Dynamic Island on supported iPhones; End becomes the highlighted red action during an active session. On iOS 17 and later, the Lock Screen and expanded Dynamic Island can pause/resume, add five minutes to a countdown, or end the session directly (count-up sessions omit the extension action). iOS 16.1–16.x keeps the read-only presentation. Allow notifications and make sure Live Activities are enabled under Settings > Pomodoro Bar.

The quote button in the top-right corner opens Daily Guidance with Chinese dates such as “2026年9月17日 星期四”. You can edit and save today’s entry or any non-empty historical entry from the most recent 30 calendar days; edit mode shows only the selected date’s card for a focused workspace. Editing and display states share the same warm-amber font size, line spacing, padding, and wrapping width. Data syncs automatically through CloudKit. The configuration button can still import a legacy `daily-guidance.json`; the original file is backed up and mirrored, never deleted. Completed iOS sessions merge with Mac sessions, while active timers and device preferences remain local to each device.

## Record Format

```json
[
  {
    "id" : "36f7095d-4bc6-4290-9044-e893f05d3117",
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

`id` is the stable cross-device deduplication identifier. When a legacy JSON file has no ID, the app derives a compatible ID from its existing fields without deleting the original record.

## Data Location

`records.json` and `daily-guidance.json` are stored by default in:

```text
~/Library/Mobile Documents/com~apple~CloudDocs/PomodoroBar/
```

When iCloud Drive is unavailable or unwritable, the app falls back to:

```text
~/.pomodoro-status-bar/
```

These JSON files are readable Mac-side copies; the CloudKit private database is the primary sync source between Mac and iPhone. Existing local records are deduplicated and merged without deleting the original local file. `daily-guidance.json` stores plain-text Daily Guidance content by date.

Before the first migration, the Mac copies existing JSON files to:

```text
~/.pomodoro-status-bar/Legacy Backups/<timestamp>/
```

iOS also retains legacy session and guidance backups under the app's Application Support directory. The app issues no CloudKit delete operations. If the device is offline or iCloud is temporarily unavailable, it continues writing local JSON and merges after service returns.
