# Full Source Learning Comments

## Goal

Add detailed beginner-oriented Chinese comments to the Mac app, iOS app, Live Activity, and build scripts so the code can be learned and maintained manually.

## Changes

- Document every Swift source file with its responsibility, type roles, state properties, major methods, data flow, and important platform APIs.
- Organize long files with `MARK` sections and explain timer state transitions, persistence, iCloud file authorization, SwiftUI/UIKit/AppKit bridging, Live Activities, and App Intent communication.
- Explain each build and restart script section, including inputs, outputs, safety measures, and execution flow.
- Add Chinese and English source-reading guides covering project structure, recommended reading order, common modification points, and verification steps.
- Explain design reasons and maintenance cautions without restating every self-evident syntax line or changing behavior.

## Affected Files

- `Sources/main.swift`
- `iOS/DailyGuidance/**/*.swift`
- `scripts/build.sh`
- `scripts/restart.sh`
- `docs/code-reading-guide.md`
- `docs/en/code-reading-guide.md`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260918-1125-source-learning-comments.md`
- `docs/en/tasks/task-20260918-1125-source-learning-comments.md`

## Estimated Code Changes

Approximately 1,000–1,600 lines of comments and learning documentation, with no new business logic.

## Verification Focus

- Keep comments consistent with the current implementation without hiding or overwriting other in-progress changes.
- Pass Swift type checks, the macOS build, shell syntax checks, and diff checks.

## Actual Changes

- Added Chinese file overviews, type and method documentation, state-flow explanations, and maintenance cautions across the Mac app, iPhone app, Live Activity, App Intents, shared session model, and both scripts.
- Organized long files with `MARK` sections and documented wall-clock timing, lifecycle restoration, record compatibility, iCloud fallback, security-scoped bookmarks, App Groups, and Lock Screen action synchronization.
- Added Chinese and English source-reading guides covering project structure, reading order, major data flows, common modification points, safety principles, and verification checklists.
- Added source-reading links to both READMEs without changing business behavior or data formats.

## Verification Results

- The iOS main app and Live Activity extension separately passed type checking against the iPhoneOS SDK.
- `./scripts/build.sh` succeeded with only the known deprecated Mac notification API warnings.
- `bash -n scripts/build.sh scripts/restart.sh` and `git diff --check` passed.
- All source changes were verified as comment-only additions; no existing business code was removed or replaced.
