# 构建前备份旧 app

## 目标

每次 build 前，如果已有 `dist/PomodoroBar.app`，先在同目录备份旧版本。

## 改动

- 备份名使用原文件名加时间后缀，例如 `PomodoroBar.app.20260728-213000`。
- 备份放在 `dist/` 同目录。
- 备份完成后再生成新的 `PomodoroBar.app`。

## 影响文件

- `scripts/build.sh`
- `docs/tasks/2026-07-28-backup-app-before-build.md`

## 预估代码行数

约 10 行。

## 实际

已实现；build 前如果存在 `dist/PomodoroBar.app`，会备份为 `PomodoroBar.app.YYYYMMDD-HHMMSS`。`./scripts/build.sh` 通过，并验证生成了备份目录。
