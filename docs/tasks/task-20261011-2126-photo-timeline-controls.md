# 照片时间线视图与删除

## 目标

让一屏能看到更多时间点、允许删除行程中的照片，并修复「添加照片」误触首张照片的问题。

## 改动

- 在时间线顶部加入「大图 / 小图」切换，记住上次选择；小图模式以紧凑横排展示缩略图、时间、备注和与上一站的时间差。
- 为时间点增加删除入口和确认提示；只从当前行程删除 App 内的照片副本及时间点，不修改系统相册。删除前备份照片副本和时间点信息。
- 将照片卡片的点击范围限制在可见区域，避免竖图裁剪后的隐形区域挡住「添加照片」。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `docs/tasks/task-20261011-2126-photo-timeline-controls.md`
- `docs/en/tasks/task-20261011-2126-photo-timeline-controls.md`

## 预估代码行数

约 160 行。

## 验证重点

用竖图检查「添加照片」的点击范围；检查切换视图、删除后时间差重算、重启后的结果，以及系统相册原图不受影响。
