# 显示照片的具体地点

## 目标

照片有 GPS 时，尽量显示商场等具体场所名称。

## 改动

- 优先使用地图返回的兴趣点名称，取不到时保留市区名称。
- 在照片编辑页提供重新识别地点，供已导入照片使用；不自动覆盖用户填写的地点。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- 本 task 的中英文文档

## 预估代码行数

约 30–50 行。
