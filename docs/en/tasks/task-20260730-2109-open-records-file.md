# Replace Clear Records with Open Record File

## Goal

Remove the dangerous “Clear Records” action and provide a safe way to open `records.json`.

## Changes

- Remove the Clear Records menu action, confirmation alert, and pre-clear backup logic.
- Add an “Open Record File...” menu action that opens `records.json` with the default application.
- Create readable empty JSON first when the file does not exist.
- Update the Chinese and English README and TODO files.

## Affected Files

- `Sources/main.swift`
- `README.md`
- `docs/en/README.md`
- `docs/TODO.md`
- `docs/en/TODO.md`
- `docs/tasks/task-20260730-2109-open-records-file.md`
- `docs/en/tasks/task-20260730-2109-open-records-file.md`

## Estimated Code Changes

Remove approximately 55 lines and add approximately 10 lines of code plus minor documentation.

## Actual Changes

- Removed the Clear Records menu action, confirmation alert, backup message, and backup helper.
- Added “Open Record File...” to open `records.json` with the default application.
- When no record file exists, the existing save path first creates readable `[]` JSON.
- If opening fails, an error alert shows the complete file path.
- Updated the Chinese and English README and TODO files.

## Verification

- No clear-records or pre-clear backup entry points remain in the source.
- `./scripts/build.sh` completed successfully.
- `git diff --check` passed.
- The build only reports the existing `NSUserNotification` API deprecation warnings.
