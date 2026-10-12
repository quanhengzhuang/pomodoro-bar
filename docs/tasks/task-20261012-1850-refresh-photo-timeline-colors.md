# 更新旅途留影色调

## 目标

让旅途留影呈现更明快、年轻的旅行手账气质，同时保持照片和时间信息清晰。

## 改动

- 主色改为亮紫蓝 `#5546DB`，用于日期圆圈、时间和可点击信息；主要操作使用莓果色 `#D3326A`。
- 背景使用浅紫白 `#F8F7FF`，辅助底色使用淡紫 `#EEEAFE`，正文使用深蓝黑 `#202442`。
- 超过两小时仍用琥珀黄系，低于二十分钟仍用绿色系；同步调整这两种颜色的对比度。
- 统一首页、行程页与编辑入口的色彩，不改布局、字体和照片裁切。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `docs/tasks/task-20261012-1850-refresh-photo-timeline-colors.md`
- `docs/en/tasks/task-20261012-1850-refresh-photo-timeline-colors.md`

## 预估代码行数

约 40–60 行。
