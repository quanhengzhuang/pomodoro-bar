# 调整照片时间线卡片

## 目标

恢复大图照片的显示比例，并简化卡片时间信息与时间线日期标识。

## 改动

- 大图照片按原先较宽的横向比例显示，日期圆圈增大并显示年份与月日。
- 照片下方只显示时间；时间与地点使用相同字号、颜色，备注字号增大。
- 大图和小图的时间差移除「距上一站」，大图时间差居中。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261012-2008-refine-photo-timeline-cards.md`
- `docs/en/tasks/task-20261012-2008-refine-photo-timeline-cards.md`

## 预估代码行数

约 35–55 行。
