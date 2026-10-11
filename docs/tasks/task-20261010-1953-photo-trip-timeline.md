# 照片旅行时间线 App

## 目标

新增独立的 iPhone App，将旅行照片按拍摄时间排成时间线，方便回看每站时间与相邻两站的时间差。

## 改动

- 新建独立的 SwiftUI iOS App 与 Xcode 工程，按行程组织照片。
- 支持一次导入多张照片，优先读取拍摄时间并按时间排序；缺少时间时允许手动补录或修改。
- 每张照片形成一个时间点，可添加地点或事件备注；时间线显示与上一时间点的间隔。
- 将行程、照片副本、时间和备注保存在 App 本地，重新打开后仍可查看和编辑。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline.xcodeproj/`
- `iOS/PhotoTimeline/PhotoTimeline/`（App、时间线界面、照片导入与本地存储）
- `docs/tasks/task-20261010-1953-photo-trip-timeline.md`
- `docs/en/tasks/task-20261010-1953-photo-trip-timeline.md`
- `README.md` 与 `docs/en/README.md`

## 预估代码行数

约 600 行。

## 数据与验证重点

- 导入不改动系统相册中的原照片；照片时间缺失、跨日及同一时间的排序和间隔需正确处理。
