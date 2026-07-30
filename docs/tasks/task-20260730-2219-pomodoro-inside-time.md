# 今日完成改为番茄内时间

## 目标

菜单中的“今日完成”改为“番茄内时间”。

## 改动

- 删除“今日完成：X 个番茄 · 共 Y 段”这一行。
- 改为显示当天有效计时时长：`番茄内时间：X 小时 Y 分钟`。
- 和现有“番茄外时间”配套展示。

## 影响文件

- `Sources/main.swift`
- `TODO.md`
- `docs/en/TODO.md`
- `docs/tasks/task-20260730-2219-pomodoro-inside-time.md`
- `docs/en/tasks/task-20260730-2219-pomodoro-inside-time.md`

## 预估代码行数

约 20 行。

## 实际

已实现；菜单显示 `番茄内时间` 和 `番茄外时间`，两者共用当天有效计时计算。`./scripts/build.sh` 通过。
