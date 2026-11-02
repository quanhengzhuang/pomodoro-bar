# Daily Guidance Open and Edit Activity

## Goal

Record when Daily Guidance is opened and edited, then show 24 hourly activity squares below each visible day's guidance.

## Changes

- Log an “open” when the Mac menu containing guidance opens or the iPhone guidance screen is entered; automatic refreshes do not count.
- Log an “edit” only when changed guidance is saved successfully; cancellation, unchanged content, and failed saves do not count.
- Add a separate readable `guidance-activity.json` containing individual event types and timestamps. Summarize by the event's local calendar day and hour; editing takes precedence over opening within the same hour.
- Show a row of squares for hours 00–23 beneath today's and historical guidance on Mac and beneath today's card and dated timeline cards on iPhone: light for opens, dark for edits, empty otherwise, with hour/legend and accessibility descriptions.

## Affected files

- `Sources/main.swift`
- `Sources/GuidanceActivityLog.swift`
- `iOS/Pomodoro/Pomodoro/GuidanceStore.swift`
- `iOS/Pomodoro/Pomodoro/ContentView.swift`
- `iOS/Pomodoro/Pomodoro.xcodeproj/project.pbxproj`
- `scripts/build.sh`
- `Tests/GuidanceActivityLogTests.swift`
- `README.md`, `docs/en/README.md`
- This task's Chinese and English documents

## Estimated code lines

Approximately 220–350 lines of Swift changes.

## Data and verification focus

Do not change or overwrite the existing `daily-guidance.json`. Initially keep the activity log separately on each device (Mac: `~/.pomodoro-status-bar/`; iPhone: its app container), with no CloudKit/iCloud Drive merging. A missing log means no activity. Verify day boundaries, edits overriding opens within an hour, failed saves, and the 24-hour layout.

## Result

Completed: opening the Mac menu or iPhone guidance screen records an open; a changed and successfully saved entry records an edit. Today's and historical guidance display 24 hourly activity squares. The existing guidance JSON is unchanged, and a corrupt activity log is never overwritten. Tests pass for day boundaries, edit precedence within an hour, readable JSON, and corrupt-log protection. The Mac build and an unsigned generic iOS build both pass.
