# Provide Chinese and English Versions of All Documentation

## Goal

Provide Chinese and English versions of every Markdown document in the repository.

## Changes

- Keep the existing Chinese file paths and mirror English files under `docs/en/`.
- Add language-switch links only to the Chinese and English README files.
- Move the existing `docs/TODO.en.md` and `docs/tasks/*.en.md` files into the new directory structure.
- Translate existing content while preserving commands, paths, code blocks, and technical meaning.
- Update both TODO versions after completion.

## Affected Files

- `README.md`, `docs/en/README.md`
- `AGENTS.md`, `docs/en/AGENTS.md`
- `docs/TODO.md`, `docs/en/TODO.md`
- `docs/tasks/*.md`, `docs/en/tasks/*.md`
- `docs/tasks/task-20260730-2055-bilingual-documentation.md`
- `docs/en/tasks/task-20260730-2055-bilingual-documentation.md`

## Estimated Code Changes

0 lines of code and approximately 650 lines of documentation.

## Actual Changes

- Kept Chinese documents at their original paths and mirrored English documents under `docs/en/`.
- Added language-switch links to the Chinese and English README files only; AGENTS, TODO, and task documents have no language links.
- Migrated the old `docs/TODO.en.md` and `docs/tasks/*.en.md` files into the new directory structure.
- Preserved commands, paths, code blocks, and task status consistently in English.

## Verification

- Every Chinese Markdown document has a corresponding English file under `docs/en/`.
- Only the Chinese and English README files contain language-switch links.
- `git diff --check` passed.
