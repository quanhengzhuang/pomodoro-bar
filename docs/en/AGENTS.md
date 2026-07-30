# AGENTS.md

## Development Workflow

- For non-trivial changes, write a task first and wait for user confirmation before coding.
- Store tasks at `docs/tasks/task-{YYYYMMDD}-{HHmm}-{title}.md`, for example `docs/tasks/task-20260101-0930-icon-consistency.md`.
- Keep tasks minimal and always include: goal, changes, affected files, and estimated code changes.
- Add extra sections only when data, compatibility, risk, or verification details genuinely matter.
- Provide Chinese and English versions of every document: keep Chinese at the original path and mirror English under `docs/en/`.
- Add language-switch links only to the Chinese and English README files.
- Push to Git promptly after completing a task.

## Data Compatibility

- Record file: `~/.pomodoro-status-bar/records.json`.
- Changes to the record format, path, duration semantics, clearing, or migration must remain compatible with old data.
- Never delete user data; back it up before destructive operations.
- Keep JSON readable.

## Build and Commit

- Run `./scripts/build.sh` after source or packaging configuration changes.
- Do not commit `dist/` or `.build/`.
- Check `git status --short --branch` before committing.
