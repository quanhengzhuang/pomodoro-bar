# Add Daily Guidance to the iOS Summary

## Goal

Change the home summary to three cells: Daily Guidance (set/not set), the existing focus duration, and the existing completed-session count. Remove the final Live Activity status cell and make the Daily Guidance cell open the Daily Guidance page.

## Changes

- Keep the existing summary layout and the two timer statistics.
- Make the first cell a tappable Daily Guidance entry point, retaining the file-selection flow when no file has been selected.
- Remove the final Live Activity status cell while keeping the quote button in the top-right corner.

## Affected files

- `iOS/DailyGuidance/DailyGuidance/ContentView.swift`
- Both versions of this task document

## Estimated code lines

Approximately 25–45 lines.

## Result

Completed. The home summary now shows Daily Guidance status, today's focus duration, and completed sessions; the pending Live Activity status was removed. The Daily Guidance summary cell and the quote button share the same opening logic, and the file picker remains the first-use path when no JSON has been selected.

Build verification: both the simulator and generic iOS builds failed during asset compilation because CoreSimulator is unavailable and no simulator runtime can be found in this environment. On-device or simulator UI verification remains outstanding.
