# 详细页原地编辑与空白行程入口

## 目标

让详细页可原地修改标题并直接删除照片；首页加号直接进入标题为「一段旅程」的空白详细页。

## 改动

- 将标题修改从弹窗改为详细页内的输入与保存操作。
- 编辑状态下在大图和小图时间线的每张照片上显示删除按钮，并保留删除确认。
- 首页加号创建空白行程并立即进入详细页，照片选择页点击保存后才导入照片。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `docs/tasks/task-20261014-1925-inline-trip-editing.md`
- `docs/en/tasks/task-20261014-1925-inline-trip-editing.md`

## 预估代码行数

约 130–180 行。
