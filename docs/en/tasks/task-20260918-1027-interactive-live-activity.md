# Interactive Dynamic Island Live Activity

## Goal

Pause, resume, extend, or end the current Pomodoro session directly from the expanded Dynamic Island and Lock Screen Live Activity while keeping the app state consistent.

## Changes

- Configure an App Group for the main app and Live Activity extension to share the current session state and action requests while remaining compatible with existing in-app session data.
- Add iOS 17+ `AppIntent` actions for pause/resume, adding five minutes to a countdown, and ending the current session; hide the extension action for count-up sessions.
- Align the action hierarchy across the main app, expanded Dynamic Island, and Lock Screen: Start is the tomato-red primary action before a session begins; once active, End becomes the highlighted red action while pause/resume and extension use secondary styling.
- Update Live Activity time and state immediately after each action; reconcile shared state when the app returns to the foreground so the island and main UI cannot diverge.
- Keep the existing read-only Live Activity on iOS 16.1–16.x; compact and minimal Dynamic Island presentations remain focused on the timer.
- Update both READMEs with system-version and interaction details.

## Affected Files

- `iOS/DailyGuidance/DailyGuidance.xcodeproj/project.pbxproj`
- `iOS/DailyGuidance/DailyGuidance/`
- `iOS/DailyGuidance/PomodoroLiveActivity/`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260918-1027-interactive-live-activity.md`
- `docs/en/tasks/task-20260918-1027-interactive-live-activity.md`

## Estimated Code Changes

Approximately 250–380 lines of Swift, capability configuration, and minor documentation updates.

## Compatibility and Verification Focus

- Do not change the existing `records.json` format; ending a session shorter than three minutes still writes no record, and an eligible ended session is recorded only once.
- Verify pause/resume, extension, and end actions while the app is foregrounded, backgrounded, or terminated, including local-notification rescheduling and cancellation.
- Verify Lock Screen and Dynamic Island actions on the connected iOS 26 device; check iOS 16.1 compilation compatibility and iOS 17 availability isolation.

## Verification Results

- The main app sources passed type checking with an iOS 16.1 target. The Live Activity extension compiled with the same deployment target, including successful iOS 17+ App Intent metadata extraction.
- The App Group entitlements for both targets, the extension `Info.plist`, and the Xcode project all passed format validation; the generated extension bundle contains a valid executable.
- A signed generic iPhone Debug build completed successfully. The App Group entitlement was applied to the main app, and the embedded Live Activity extension passed signing and bundle validation.
- The previously identified iPhone is not currently listed as an available Xcode destination, so the Lock Screen and Dynamic Island interaction layout still needs confirmation after the device reconnects.
