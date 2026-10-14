# 从照片创建行程

## 目标

首页点击加号后直接选择照片，保存后自动生成随机标题。

## 改动

- 首页加号和空白页入口打开现有照片选择界面，不再要求先输入标题。
- 选中照片后一次保存行程与照片引用；没有成功添加照片时不创建空行程。
- 从预设行程标题中随机选取一个，之后仍可重命名。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `docs/tasks/task-20261014-1909-create-trip-from-photos.md`
- `docs/en/tasks/task-20261014-1909-create-trip-from-photos.md`

## 预估代码行数

约 70–100 行。
