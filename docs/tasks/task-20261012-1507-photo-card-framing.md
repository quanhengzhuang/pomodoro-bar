# 调整时间线照片显示位置

## 目标

让用户调整照片在时间线卡片中的裁切位置，保留想看的画面主体。

## 改动

- 在时间点编辑页提供可拖动的卡片预览及水平、垂直位置滑块，支持重置到居中；保存后用于大图和小图模式。
- 根据照片与卡片的尺寸限制拖动范围，避免露出空白；只改变显示位置，不修改照片原文件。
- 为每个时间点保存归一化的显示位置；旧行程未保存该值时保持原来的居中效果。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `docs/tasks/task-20261012-1507-photo-card-framing.md`
- `docs/en/tasks/task-20261012-1507-photo-card-framing.md`

## 预估代码行数

约 120–170 行。

## 验证重点

检查横图、竖图在两种模式的裁切效果、拖动边界、重启后位置保留，以及旧行程可正常读取。
