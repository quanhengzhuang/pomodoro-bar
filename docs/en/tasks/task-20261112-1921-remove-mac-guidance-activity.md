# Remove Mac Daily Guidance Activity

## Goal

Stop recording and displaying Daily Guidance open/edit activity on Mac while keeping the 24-hour activity squares and local activity log on iPhone.

## Changes

- Remove Mac activity-log loading, writing, and the `guidance-activity.json` path.
- Remove the 24-hour activity strip below today's and historical guidance on Mac.
- Keep the iPhone activity log, activity squares, data format, and existing `daily-guidance.json` unchanged.
- Update the Chinese and English README and task notes.

## Affected files

- `Sources/main.swift`
- `Sources/GuidanceActivityLog.swift`
- `README.md`
- `docs/en/README.md`
- This task's Chinese and English documents

## Estimated code lines

Approximately 70–110 deleted lines plus documentation updates.

## Verification focus

After the Mac build, its menu should no longer show an activity strip. The iPhone target should still compile and display the activity strip. Neither `daily-guidance.json` nor the iPhone activity log should change.

## Result

Completed. Mac activity-log reads/writes and the menu activity strip are removed; iPhone keeps the activity log and 24-hour squares. Any old Mac activity log is left untouched and is no longer read or written, and the existing guidance JSON is unchanged.
