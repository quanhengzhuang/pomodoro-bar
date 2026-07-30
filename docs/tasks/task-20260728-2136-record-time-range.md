# 菜单记录显示时间段

## 目标

菜单记录显示真实开始-结束时间，并保留实际分钟数。

## 改动

- 记录格式改为：`2026-07-28 16:59-17:04 · 休息 · 5 分钟`。
- 有备注时追加：`· 整理排期说明`。
- 秒继续省略，彩色圆点保留。

## 影响文件

- `Sources/main.swift`
- `docs/tasks/task-20260728-2136-record-time-range.md`

## 预估代码行数

约 10 行。

## 实际

已实现；菜单分钟数由 `startedAt` 到 `endedAt` 计算，解析失败才回退到 `durationMinutes`。`./scripts/build.sh` 通过，只有既有通知 API deprecated 警告。
