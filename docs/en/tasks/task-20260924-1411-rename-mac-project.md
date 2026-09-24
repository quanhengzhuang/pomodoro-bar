# Remove “Bar” from the Mac Project Name

## Goal

Rename the Mac project and build product from `PomodoroBar` to `Pomodoro`, removing `Bar` while preserving Bundle Identifier, status-item instance identity, and existing data-directory compatibility.

## Changes

- Update the Mac build script, Info.plist, restart script, and related README/documentation references.
- Keep `local.codex.PomodoroBar`, the `PomodoroBar` data directory, and process compatibility logic unchanged so existing installations and data remain usable.
- Build and verify the new product name; do not commit `dist/` or `.build/`.

## Affected files

- `scripts/build.sh`
- `scripts/restart.sh`
- `Packaging/Info.plist`
- `README.md`, `docs/en/README.md`, and related bilingual documentation

## Estimated code lines

Approximately 20–40 lines.

## Result

The Mac build product and displayed name are now `Pomodoro.app` / `Pomodoro`; the existing Bundle Identifier and `PomodoroBar` data directory are unchanged. `./scripts/build.sh` and shell syntax checks passed. The new bundle's executable, display name, and identifier were verified. The older `dist/PomodoroBar.app` was not deleted.
