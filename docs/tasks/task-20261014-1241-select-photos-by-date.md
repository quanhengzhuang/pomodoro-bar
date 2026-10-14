# 添加照片时按日期定位

## 目标

点击「添加照片」后可选择日期，直接查看并选入当天照片。

## 改动

- 新增按日期浏览的照片选择界面，显示选定日期的照片并支持多选。
- 保留系统照片选择器作为「浏览全部照片」入口，以及照片授权受限时的替代方式。
- 将按日期选中的照片导入现有行程，沿用原始文件、拍摄时间、地点及缩略图的保存方式。
- 添加读取照片图库的用途说明。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `iOS/PhotoTimeline/PhotoTimeline.xcodeproj/project.pbxproj`
- `docs/tasks/task-20261014-1241-select-photos-by-date.md`
- `docs/en/tasks/task-20261014-1241-select-photos-by-date.md`

## 预估代码行数

约 170–230 行。
