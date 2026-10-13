# 调整照片备注与时间差信息

## 目标

让备注出现在照片上方，缩小辅助文字，并统一时间差颜色。

## 改动

- 有备注时在大图卡片的照片上方显示备注，字号改为较小的常规文字。
- 大图与小图的时间、地点字号各缩小一级。
- 时间差及时间线连接线统一使用常规主题色，移除超过 2 小时与低于 20 分钟的特殊配色。
- 页面和行程标题改用系统普通字体，不再使用衬线字体。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261013-1102-note-above-photo.md`
- `docs/en/tasks/task-20261013-1102-note-above-photo.md`

## 预估代码行数

约 20–35 行。
