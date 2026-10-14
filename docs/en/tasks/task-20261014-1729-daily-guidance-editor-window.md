# Resizable Daily Guidance Editor

## Goal

On macOS, double-click today's guidance text in the main menu to edit it. Esc closes the editor and discards unsaved changes. The editor window can be resized, and the text area resizes with it.

## Changes

- Add double-click editing only to today's guidance text in the main menu; keep historical guidance read-only and retain the existing “Edit Today's Guidance...” entry.
- Replace the fixed-size editing alert with a resizable window whose text area tracks its size; define Save, Cancel, and Esc behavior.
- Keep the existing JSON storage and merge-before-save behavior without changing the data format or path.

## Files affected

- `Sources/main.swift`

## Estimated code lines

About 80–130 lines added or changed.
