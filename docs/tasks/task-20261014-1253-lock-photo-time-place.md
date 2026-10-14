# 锁定照片时间与地点

## 目标

照片的拍摄时间和地点只显示，不允许在编辑页修改。

## 改动

- 移除拍摄时间的开关、日期选择器、地点输入框和重新识别按钮。
- 编辑页只读显示时间与地点，保留备注、照片显示位置和删除功能。
- 保存接口不再接受时间或地点修改。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- 本 task 的中英文文档

## 预估代码行数

约 40–60 行。
