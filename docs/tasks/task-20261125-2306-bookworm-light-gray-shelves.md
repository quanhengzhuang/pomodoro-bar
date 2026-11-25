# 书虫页面与小组件浅灰背景

## 目标

提高白色封面在 iPhone 书单页和小组件中的轮廓辨识度。

## 改动

- 两个书单的列表与格子使用随系统外观变化的背景，浅色模式采用浅灰。
- 两个 iOS 小组件使用相同底色，去除封面描边及占位封面侧边色条，保留封面的圆角和明暗渐变。

## 影响文件

- `iOS/bookworm/App/LibraryView.swift`
- `macOS/WeReadShelf/Widget/ReadingWidgets.swift` 的 iOS 分支

## 预估代码行数

约 15–25 行 Swift。

## 验证重点

使用白色封面验证页面反差，检查小组件样式并覆盖安装 iPhone 版。
