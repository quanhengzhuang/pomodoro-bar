# 连接时间线圆点

## 目标

让大图时间线的竖线沿照片卡片延伸，接近相邻的日期圆圈和时间点圆点。

## 改动

- 在每张卡片左侧补上竖线，与时间差区段的竖线连贯；线画在圆圈和圆点后方。
- 最后一个时间点的竖线收在标识处，不向卡片底部悬空延伸。
- 时间差与距离差这一行在照片卡片对应的宽度内居中显示，较长内容可换行并保持居中。
- 保留时间差颜色、日期圆圈大小、照片宽高比和小图模式。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261012-1852-connect-timeline-markers.md`
- `docs/en/tasks/task-20261012-1852-connect-timeline-markers.md`

## 预估代码行数

约 25–40 行。
