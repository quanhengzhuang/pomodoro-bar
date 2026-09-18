# Source Reading and Maintenance Guide

This guide is for maintainers who are new to Swift, macOS AppKit, iOS SwiftUI, and Live Activities. Chinese inline comments explain local implementation details; this document first explains how the whole project fits together.

## Project Components

The repository contains three runtime units:

1. **Mac menu bar app**: `Sources/main.swift`
2. **iPhone main app**: `iOS/DailyGuidance/DailyGuidance/`
3. **Lock Screen Live Activity extension**: `iOS/DailyGuidance/PomodoroLiveActivity/`

The Mac and iPhone apps are separate programs. Both can use Daily Guidance, but timer records are currently separate: Mac records prefer iCloud, while iPhone timer records stay in the app sandbox.

The iPhone app and Live Activity extension are also separate processes. They exchange the current timer session through an App Group container.

## Recommended Reading Order

### First pass: data models

Read these files in order:

1. `iOS/DailyGuidance/DailyGuidance/PomodoroActivityAttributes.swift`
2. `iOS/DailyGuidance/Shared/PomodoroSharedSession.swift`
3. `iOS/DailyGuidance/DailyGuidance/GuidanceStore.swift`
4. `iOS/DailyGuidance/DailyGuidance/PomodoroStore.swift`

Understand these concepts first:

- `PomodoroMode`: count-up, focus, short break, or long break.
- `elapsedSeconds`: actual running time, excluding pauses.
- `displaySeconds`: elapsed time for count-up and remaining time for countdowns.
- `sessionID`: stable identity that prevents an old Lock Screen action from controlling a new session.
- `dateKey`: a Daily Guidance JSON key in fixed `yyyy-MM-dd` form.

### Second pass: iPhone UI

Read `iOS/DailyGuidance/DailyGuidance/ContentView.swift`:

- `ContentView` is the home screen.
- `GuidanceSheet` manages file state and editing sessions.
- `GuidanceTimelineView` displays the 30-day timeline.
- `GuidanceEntryCard` represents one day.
- `GuidanceStyledTextView` bridges UIKit `UITextView` into SwiftUI so editing and display wrap identically.

The important SwiftUI separation is: a View describes how state looks; a Store decides how state changes. Avoid direct JSON writes or timer business rules inside Views.

### Third pass: Lock Screen and Dynamic Island

Read:

1. `PomodoroLiveActivity/PomodoroLiveActivityBundle.swift`
2. `PomodoroLiveActivity/PomodoroLiveActivity.swift`
3. `PomodoroLiveActivity/PomodoroLiveActivityIntents.swift`

The Live Activity renders `PomodoroActivityAttributes.ContentState`. On iOS 17, buttons run App Intents that update `PomodoroSharedSession` in the App Group. The main app reconciles that state when notified or when it becomes active again.

### Fourth pass: Mac single-file app

Follow the `MARK` sections in `Sources/main.swift`:

1. Models and compatibility decoding
2. App lifecycle
3. Menu construction
4. Timer state machine
5. Daily Guidance
6. Records and statistics
7. iCloud and local fallback
8. NSMenu actions

The Mac app has no Xcode project. `scripts/build.sh` compiles `main.swift` directly with `swiftc` and assembles the `.app` directory.

## iPhone Timer Data Flow

Starting a session performs four parallel responsibilities:

```text
User taps Start
  ├─ Update @Published properties → SwiftUI refreshes
  ├─ Save PersistedSession → restore after app restart
  ├─ Save PomodoroSharedSession → Lock Screen actions can operate
  └─ Create Live Activity and completion notification
```

The foreground one-second Timer only refreshes the UI. Real elapsed time comes from:

```text
accumulated running seconds + current time - last resume time
```

Do not change this to incrementing or decrementing once per Timer callback. iOS suspends timers in the background, which would introduce large timing errors.

Pausing folds the current running segment into accumulated seconds and clears the resume date. Resuming records a new segment start.

## Live Activity Data Flow

The main app supplies:

- `sessionID` as immutable attributes;
- mode, running state, and time anchors as updateable `ContentState`.

A Lock Screen action follows this path:

```text
Live Activity button
  → App Intent validates sessionID
  → Update App Group shared session
  → Update or end ActivityKit activity
  → Reschedule or cancel completion notification
  → Main app reconciles its UI and records
```

The main app and extension each contain a copy of `PomodoroActivityAttributes` because their targets compile separately. Keep both copies synchronized when fields change.

## Daily Guidance Data Flow

The file format is:

```json
{
  "2026-09-17" : "Guidance for the first day",
  "2026-09-18" : "Today's guidance"
}
```

On first access, the iPhone user selects `daily-guidance.json` through the system file picker. The returned URL is only temporarily accessible, so `GuidanceStore` saves a security-scoped bookmark and resolves it on later launches.

Saving one day performs these steps:

1. Read the full JSON again to absorb recent changes from other devices.
2. Replace only the target date.
3. Encode readable JSON with sorted keys.
4. Atomically replace the file.
5. Rebuild today's state and the 30-day timeline.

Editing and display both use `GuidanceStyledTextView`, so font, color, line spacing, content width, and wrapping are identical. The JSON remains plain text and never stores formatting.

## Mac Storage and Compatibility

Preferred Mac directory:

```text
~/Library/Mobile Documents/com~apple~CloudDocs/PomodoroBar/
```

Fallback directory:

```text
~/.pomodoro-status-bar/
```

The app reads both local and iCloud files and merges records. If an iCloud file is unreadable, the current run avoids overwriting it and writes to the local fallback instead.

`PomodoroRecord` has a custom decoder for older fields. When changing the format:

- give new fields defaults where possible;
- never delete data the user cannot recreate;
- do not remove legacy data until migration saves successfully;
- keep JSON human-readable.

## Common Modification Points

| Need | Main files |
| --- | --- |
| Change iPhone layout or colors | `ContentView.swift` |
| Change start, pause, or completion rules | `PomodoroStore.swift` |
| Change guidance I/O or 30-day filtering | `GuidanceStore.swift` |
| Change Lock Screen/Dynamic Island layout | `PomodoroLiveActivity.swift` |
| Change Lock Screen button behavior | `PomodoroLiveActivityIntents.swift`, `PomodoroSharedSession.swift` |
| Change Mac menu, timer, or storage | `Sources/main.swift` |
| Change Mac packaging | `scripts/build.sh` |

## Safe Manual Maintenance Rules

1. **Separate display state from business state.** Colors and padding belong in Views; timers and file rules belong in Stores.
2. **Calculate time from Date differences.** Never trust Timer callback counts.
3. **Synchronize shared fields.** After changing Activity attributes or App Group models, inspect every constructor in both targets.
4. **Preserve old JSON.** Use optional/default fields and atomic writes.
5. **Capture final state before resetting memory.** Otherwise the Lock Screen final frame will contain reset values.
6. **Treat iCloud URLs as security-scoped on iPhone.** Read and write only inside the access scope.
7. **Keep UserDefaults small.** It currently stores only compact Codable session snapshots.

## Verification After Changes

For Mac source or packaging changes:

```bash
./scripts/build.sh
```

For shell syntax:

```bash
bash -n scripts/build.sh scripts/restart.sh
```

For iPhone testing, select the `PomodoroBar` scheme in Xcode and run on a device. Manually verify:

- start, pause, resume, and end;
- correct time after backgrounding and returning;
- Lock Screen and Dynamic Island actions sync to the home screen;
- completion notification fires only once;
- multiline Daily Guidance editing, past-date editing, and iCloud reload;
- identical wrapping before and during editing.

Before committing, inspect `git status --short --branch` so `dist/`, `.build/`, and unrelated drafts are not included.
