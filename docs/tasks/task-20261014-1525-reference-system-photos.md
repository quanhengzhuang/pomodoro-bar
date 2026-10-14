# 改用系统相册引用

## 目标

新添加的照片只记录系统相册引用；旧照片可删除后重新添加。

## 改动

- 新照片保存相册标识和时间、地点，不再复制原图或缩略图。
- 时间线按相册标识加载照片，失效时显示占位图。
- 旧照片保留现状，提供按行程批量移除旧照片的入口；操作前备份，完成后清理照片副本。
- 删除引用照片仅移除 App 记录，不删除系统相册原图。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `iOS/PhotoTimeline/PhotoTimeline.xcodeproj/project.pbxproj`
- 本 task 的中英文文档

## 预估代码行数

约 90–140 行。
