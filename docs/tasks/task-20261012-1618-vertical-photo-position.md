# 仅上下调整照片位置

## 目标

让照片位置调整聚焦于上下拖动，去掉体验不佳的横向滑块。

## 改动

- 编辑页预览只响应上下拖动，移除水平和垂直位置滑块。
- 保留现有照片的水平位置数据；新的拖动只修改垂直位置，“恢复垂直居中”只重置垂直位置。
- 提示文字改为“上下拖动照片调整显示位置”。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261012-1618-vertical-photo-position.md`
- `docs/en/tasks/task-20261012-1618-vertical-photo-position.md`

## 预估代码行数

约 15–25 行。
