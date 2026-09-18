# iOS Dice Tray Layout and Sequential Physics Polish

## Goal

Fix the incomplete tray view, prevent dice from leaving the tray or appearing out of nowhere, and make dice drop one at a time with each result revealed when that die settles.

## Changes

- Adjust the 3D camera, tray proportions, and safety bounds so the full table stays visible.
- Remove the behavior that repositions the whole group during a roll; add an independent throw queue and settled state for each die.
- Settle and reveal each die independently, then finish the roll after all dice have landed.
- Preserve Reduce Motion, history, and 1–10 dice layouts.

## Affected Files

- `iOS/DiceRoller/DiceRoller/DiceSceneView.swift`
- `iOS/DiceRoller/DiceRoller/ContentView.swift`

## Estimated Lines of Code

About 180 lines.
