# AGENTS.md

This file defines repository-specific instructions for AI coding agents working on Pomodoro Bar.

## Development Workflow

For every non-trivial implementation request, behavior change, refactor, or data-format change:

1. Create a task document before coding.
2. Put task documents under `docs/tasks/`.
3. Name task documents with this format:

   ```text
   docs/tasks/YYYY-MM-DD-xxxxxx.md
   ```

   Example:

   ```text
   docs/tasks/2026-06-06-custom-focus-duration.md
   ```

4. The task document must include:
   - Goal
   - Background
   - Scope
   - Non-goals
   - Data compatibility considerations
   - Implementation plan
   - Acceptance criteria
   - Verification plan
5. Stop after writing the task document and ask the user to confirm it.
6. Do not start coding until the user confirms the task document is correct.
7. After implementation, update the task document with:
   - What changed
   - Verification performed
   - Any known limitations or follow-up work

Small, obvious fixes that do not change behavior or data may be implemented directly, but mention that the task-document step was skipped because the change is trivial.

## Data Compatibility

Pomodoro Bar stores user records at:

```text
~/.pomodoro-status-bar/records.json
```

Any change to record format, storage path, duration semantics, clearing behavior, or migration behavior must preserve compatibility with existing user data.

When changing data behavior:

- Read existing records successfully.
- Preserve human-readable JSON.
- Keep existing user records unless the user explicitly requests deletion.
- Back up user data before destructive operations.
- Prefer additive migrations over destructive rewrites.
- If a field is removed or deprecated, document why and preserve safe reading of old records.
- Verify with representative old and new record examples.

## Build And Generated Files

- Use `./scripts/build.sh` to build the app.
- Build output goes to `dist/PomodoroBar.app`.
- Do not commit `dist/` or `.build/`.
- Keep source in `Sources/`, packaging metadata in `Packaging/`, and reusable static assets in `Resources/` or `docs/assets/`.

## Commit Expectations

Before committing:

- Run `./scripts/build.sh` when source or packaging changes.
- Check `git status --short --branch`.
- Keep commits focused and avoid unrelated cleanup.
