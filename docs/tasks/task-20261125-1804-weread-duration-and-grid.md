# WeReadShelf 阅读时长与格子布局

## 目标

显示微信读书提供的可用单本时长，消除书架上的「累计 0 秒」，让格子封面与下方文字更协调。

## 改动

- 单本接口改读实测回包中的 `book.readingTime`（秒），并沿用书架同步和按需查询流程。时长为零或缺失时，书单只显示最近阅读日期，详情提示「暂无可用时长」。[单本接口实测](https://github.com/MilkyWay-qt/weread-mcp#与官方-weread-skills-怎么选) · [回包示例](https://github.com/zhaohongxuan/obsidian-weread-plugin/blob/main/docs/weread-agent-api.md#bookgetprogress--阅读进度)
- 收紧格子的列宽和纵向间距，使封面与下方文字使用同一内容宽度并左对齐。书名最多两行，短书名直接接作者，悬停可查看全名。列表和选书窗口沿用 40 pt 封面。

## 影响文件

- `macOS/WeReadShelf/App/WeReadAPI.swift`、`LibraryStore.swift`、`LibraryView.swift`
- `README.md`、`docs/en/README.md`
- 本任务的中英文文档

## 预估代码行数

约 70–120 行 Swift 改动。

## 数据与验证重点

- 按当前账号缓存时长，读取旧缓存时保留已有书单和阅读日期。验证两个时长字段同时返回、时长缺失、旧缓存、刷新失败和长书名。
- 构建独立工程和仓库 `./scripts/build.sh`，更新 `dist/WeReadShelf.app`。
