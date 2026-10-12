# 恢复大图照片卡片比例

## 目标

恢复日期圆圈加入前大图照片的显示宽高比。

## 改动

- 缩小日期圆圈在时间线中占用的布局宽度，让照片卡片恢复原来的可用宽度，同时保留圆形日期标识。
- 保持照片高度和现有裁切位置数据不变。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261012-1841-restore-photo-card-ratio.md`
- `docs/en/tasks/task-20261012-1841-restore-photo-card-ratio.md`

## 预估代码行数

约 10–20 行。
