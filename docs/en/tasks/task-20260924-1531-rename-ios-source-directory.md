# Rename the iOS Source Directory

## Goal

Rename the `DailyGuidance` code directories in the iOS project to `Pomodoro` so they match the Xcode project name.

## Changes

- Rename `iOS/DailyGuidance/` to `iOS/Pomodoro/`, including its main-app source directory `DailyGuidance/` to `Pomodoro/`.
- Update the Xcode source group path, resource paths, signing settings, and related documentation references.
- Keep Swift file names, type names, Bundle Identifier, data file paths, and runtime behavior unchanged.

## Impacted Files

- `iOS/Pomodoro/`
- `iOS/Pomodoro/Pomodoro.xcodeproj/project.pbxproj`
- `README.md`
- `docs/code-reading-guide.md`
- Corresponding English documentation

## Estimated Code Lines

0 lines of logic code; approximately 20 lines of path and project configuration updates.
