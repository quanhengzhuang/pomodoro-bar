# 调整时间线信息排版

## 目标

让照片时间、地点、备注和时间差更易读，并避免显示原始坐标。

## 改动

- 时间与地点使用同样的灰色常规字重，地点靠右；仅有坐标而无地点名称时隐藏地点。
- 备注调整为介于原正文与标题之间的字号。
- 时间差精确到分钟，不显示秒；大图时间差以照片卡片为基准居中。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261012-2028-refine-timeline-metadata.md`
- `docs/en/tasks/task-20261012-2028-refine-timeline-metadata.md`

## 预估代码行数

约 30–50 行。
