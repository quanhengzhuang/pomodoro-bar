# 回退大图时间线相关样式

## 目标

撤销 `8a54600` 的卡片宽度调整，让大图时间线相关样式回到 `7f36b91` 之前（`88269a4`）的状态。

## 改动

- 恢复日期圆圈、时间线左侧占位、照片卡片间距和照片显示宽高比到 `88269a4` 的布局。
- 恢复时间与地点在卡片中的字号及时间文字缩放行为到 `88269a4` 的样式。
- 保留后续新增的年份分隔、时间差与距离、配色和其他功能，并调整时间线竖线使其与回退后的布局对齐。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261012-1926-revert-photo-timeline-layout.md`
- `docs/en/tasks/task-20261012-1926-revert-photo-timeline-layout.md`

## 预估代码行数

约 20–40 行。
