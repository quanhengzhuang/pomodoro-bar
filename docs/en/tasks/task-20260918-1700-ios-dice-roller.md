# iOS 3D Dice Roller

## Goal

Add a standalone iOS dice roller that throws 1–10 dice at once and keeps one history row per roll.

## Changes

- Create a separate SwiftUI iOS app and Xcode project without changing the existing Pomodoro app.
- Add a 1–10 dice count selector, total display, and one-line-per-roll history.
- Build the 3D throw animation with SceneKit physics, true die faces, shadows, haptics, and settle detection.
- Use a walnut dice tray and ivory dice visual direction, with Reduce Motion and VoiceOver support.

## Affected Files

- `iOS/DiceRoller/DiceRoller.xcodeproj/project.pbxproj`
- `iOS/DiceRoller/DiceRoller/DiceRollerApp.swift`
- `iOS/DiceRoller/DiceRoller/ContentView.swift`
- `iOS/DiceRoller/DiceRoller/DiceSceneView.swift`
- `iOS/DiceRoller/DiceRoller/Assets.xcassets/`

## Estimated Lines of Code

About 650 lines.
