[中文](../../README.md) | [English](README.md)

<img src="../assets/icon.png" alt="Pomodoro Bar icon" width="148">

# Pomodoro Bar · Menu Bar Pomodoro Timer

A lightweight macOS menu bar Pomodoro timer.

## Preview

<img src="../assets/screenshot-menu.png" alt="Pomodoro Bar menu preview" width="35%">

## Features

- Shows a tomato icon, countdown, and paused state in the menu bar
- Supports count-up timing from `00:00`
- Supports focus, short break, and long break sessions
- Supports a custom focus duration
- Starts the selected timer mode directly from the menu
- Press Space while the menu is open to start or pause
- Sends a macOS Notification Center alert when a session completes
- Records all Pomodoro and break sessions for the current day
- Saves records as readable JSON at `~/.pomodoro-status-bar/records.json`
- Opens the record file directly from the menu

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
