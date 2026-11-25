# 书虫推荐值与列表排版

## 目标

让列表在浅灰底上通过行距区分书目，显示微信读书推荐值和字数，并合并阅读日期与时长。

## 改动

- iPhone 书单页面及小组件的浅色底更新为参考图书架底色 `#F4F5F7`，深色模式沿用系统色。
- 两个列表去掉横线，使用行距区分书目，统一放大封面。作者下方分别显示「推荐值  |  字数」和「日期  |  累计时长」，分享长图沿用该信息。
- 通过微信读书单本详情接口获取并缓存推荐值和字数，兼容已有书单缓存。

## 影响文件

- `iOS/bookworm/App/LibraryView.swift`
- `macOS/WeReadShelf/App/LibraryStore.swift`、`macOS/WeReadShelf/App/WeReadAPI.swift`
- `macOS/WeReadShelf/Shared/ReadingModels.swift`、`macOS/WeReadShelf/Widget/ReadingWidgets.swift`

## 预估代码行数

约 85–140 行 Swift。

## 验证重点

核对背景取样、列表排版、推荐值和字数换算及缺失字段，编译并安装真机版。
