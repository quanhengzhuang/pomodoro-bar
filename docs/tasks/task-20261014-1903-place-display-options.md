# 地点显示选项

## 目标

让时间线地点可选择显示“城市＋具体地点”“城市＋区名”或不显示。

## 改动

- 保存地图识别出的城市、区名和具体地点，已有 GPS 照片重新识别一次。
- 在行程菜单加入地点显示选项，作用于大图和小图时间线。
- 默认显示“城市＋具体地点”；没有具体地点时回退到“城市＋区名”。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- 本 task 的中英文文档

## 预估代码行数

约 70–100 行。
