# Copy and Paste in the Mac Daily Guidance Editor

## Goal

Support standard copy, paste, cut, and select-all shortcuts in the Mac Daily Guidance dialog's multiline editor.

## Changes

- Configure a standard AppKit Edit menu so ⌘C, ⌘V, ⌘X, and ⌘A route to the focused text input.
- Keep the Daily Guidance JSON format, save behavior, data directory, and timer logic unchanged.
- Build and inspect the menu configuration; verify shortcuts in the dialog when a graphical environment is available.

## Affected files

- `Sources/main.swift`
- Both versions of this task document

## Estimated code lines

Approximately 20–35 lines.

## Result

Added a standard Edit menu to the menu-bar-only app, routing ⌘X/⌘C/⌘V/⌘A to the focused text field through the responder chain. `./scripts/build.sh` passed. The app was not launched for UI testing to avoid interrupting an active timer; verify the shortcuts manually in the dialog.
