# Goal

- Use the existing menu bar tomato icon as the reference, align the application icon and README icon, and verify the packaged icon path.

# Changes

- Inspect `Resources/AppIcon.icns`, `docs/assets/icon.png`, the menu bar drawing logic, and the packaging script’s icon reference.
- Generate the application and README icons using the current tomato icon’s colors, shape, and highlight.
- Explicitly load the application icon at startup and use the same icon in every settings and confirmation alert to avoid stale system-cached icons.
- Confirm that the built application still uses `AppIcon.icns`.

# Affected Files

- `Sources/main.swift`
- `Resources/AppIcon.icns`
- `docs/assets/icon.png`
- `Packaging/Info.plist`
- `scripts/build.sh`
- `docs/tasks/task-20260730-1126-icon-consistency.md`

# Estimated Code Changes

- Approximately 12 lines of code and one updated image asset.

# Actual Changes

- The menu bar drawing and `docs/assets/icon.png` already matched and were left unchanged.
- Generated and replaced `Resources/AppIcon.icns` using the existing visual design from `docs/assets/icon.png`.
- Explicitly set the application icon at startup and applied the bundled icon consistently to note, clear-records, clear-complete, focus-duration, and invalid-duration alerts.
- The application icon references in `Packaging/Info.plist` and `scripts/build.sh` were correct and left unchanged.

# Verification

- `./scripts/build.sh` completed successfully with only the existing notification API deprecation warnings.
- The packaged `AppIcon.icns` exactly matches `Resources/AppIcon.icns`.
- All five `NSAlert` entry points load the new icon from the application bundle through the shared helper.
