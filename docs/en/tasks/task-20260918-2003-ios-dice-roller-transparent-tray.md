# iOS Transparent Tray and Sequential Dice Settling

## Goal

Remove the awkward square-window treatment, keep dice visible on the table before a roll, and settle them one at a time within the table while accumulating results.

## Changes

- Remove the heavy outer brown window and decorative frame; keep only a transparent, borderless container around the SceneKit table.
- Do not hide or move dice at roll start; give each die independent velocity and spin from its current tabletop position.
- Add per-die settling detection that immediately reports and adds each result; write one history row after all dice settle.
- Strengthen table bounds and timeout recovery so dice never leave the visible table or snap back into place.

## Affected Files

- `iOS/DiceRoller/DiceRoller/ContentView.swift`
- `iOS/DiceRoller/DiceRoller/DiceSceneView.swift`

## Estimated Lines of Code

About 140 lines.
