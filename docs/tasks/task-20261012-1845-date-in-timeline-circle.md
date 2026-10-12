# 日期移入时间线圆圈

## 目标

让大图时间线的日期集中显示在左侧圆圈，照片下方只显示拍摄时间。

## 改动

- 每天的日期圆圈固定显示月日和年份，不再仅跨年时显示年份。
- 大图卡片的时间改为 `HH:mm`；地点仍在同一行，缺少拍摄时间时保留补录提示。
- 时间文字使用蓝色，与深色备注区分；缺少拍摄时间的提示仍用现有警示色。
- 小图模式保持现有日期显示。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261012-1845-date-in-timeline-circle.md`
- `docs/en/tasks/task-20261012-1845-date-in-timeline-circle.md`

## 预估代码行数

约 10–20 行。
