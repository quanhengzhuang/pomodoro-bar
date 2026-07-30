[中文](../../README.md) | [English](README.md)

<img src="../assets/icon.png" alt="Pomodoro Bar icon" width="148">

# Pomodoro Bar · Menu Bar Pomodoro Timer

A lightweight macOS menu bar Pomodoro timer.

## Preview

<img src="../assets/screenshot-menu.png" alt="Pomodoro Bar menu preview" width="35%">

## Features

- Use a free-running timer from `00:00`, or follow a Pomodoro rhythm with 25-minute focus and 5/15-minute breaks
- Control everything from the menu bar: start, pause, resume, extend, or end while keeping progress visible
- Press Space while the menu is open to start, pause, or resume instantly
- Add a note to the current session and keep it with the record
- Receive a macOS notification when a focus or break session finishes
- Review today’s sessions with their time range, active duration, and notes
- No account required—your data stays on your Mac and can be opened from the menu at any time

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
