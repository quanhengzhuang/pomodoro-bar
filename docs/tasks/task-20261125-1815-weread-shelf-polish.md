# WeReadShelf 书单交互与图标

## 目标

整理格子间距与书单操作，使用受参考图启发的蓝底叠书图标。

## 改动

- 格子横向和纵向间距各增加 4 pt，封面和文字继续共用 110 pt 内容宽度。
- 移除阅读数据弹窗。点击时钟直接查询或刷新单本累计时长，结果显示在书卡或列表原位置。
- 将界面和桌面小组件里的「自定义书单」改名为「我的书单」。在列表或格子中移除书籍时，先显示书名和「取消」「移出」按钮，确认后更新书单。
- 采用用户选定的蓝底白线叠书图，保留原图构图并导出各尺寸 macOS 图标资源。

## 影响文件

- `macOS/WeReadShelf/App/LibraryView.swift`、`macOS/WeReadShelf/Shared/ReadingModels.swift`
- `macOS/WeReadShelf/App/Assets.xcassets/AppIcon.appiconset/`
- `README.md`、`docs/en/README.md` 和本任务的中英文文档

## 预估代码行数

约 50–90 行 Swift 改动，另有图标图片。

## 数据与验证重点

- 沿用已有书单、小组件和深链接标识。验证取消与确认移除、单本刷新和图标打包，构建仓库并更新 `dist/WeReadShelf.app`。
