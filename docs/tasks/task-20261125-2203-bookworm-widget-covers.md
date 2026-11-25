# 书虫 iPhone 小组件封面与阅读跳转

## 目标

让「最近阅读」和「我的书单」的主屏幕小组件以封面为主，点封面即可前往对应的微信读书页面。

## 改动

- 中号以一排四本为上限，显示直角封面和单行书名。小号聚焦第一本。使用书虫的标题图标与配色，缺少封面时用带书名的占位图。
- 在 iOS 的 App Group 中缓存缩略图。书单更新后补齐当前封面，下载完成后刷新小组件。离线时使用缓存。
- 点按封面后，iOS 将链接交给书虫，书虫随即尝试打开微信读书。优先用接口给出的阅读链接，按可用情况使用详情链接或网页。空白区域及缺少链接时可进入对应书单。

## 影响文件

- `iOS/bookworm/App/LibraryView.swift`
- `macOS/WeReadShelf/Widget/ReadingWidgets.swift`
- `macOS/WeReadShelf/Shared/ReadingModels.swift`、`macOS/WeReadShelf/Shared/WidgetSnapshotStore.swift`
- `macOS/WeReadShelf/App/LibraryStore.swift`

## 预估代码行数

约 160–260 行 Swift。

## 数据与验证重点

沿用原有小组件标识、App Group 和书单数据。用样例封面检查小号、中号、两份书单及单本跳转，验证 iOS 真机构建并覆盖安装。运行 `./scripts/build.sh`。
