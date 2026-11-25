# 书虫列表自动加载阅读时长

## 目标

让「我的书单」和「最近阅读」自动加载所有书目的累计阅读时长，并统一 iPhone 列表的封面尺寸及字号。

## 改动

- 按书目逐个查询两个列表的阅读时长，复用缓存和进行中的请求；下拉同步可重新查询。兼容单本接口的两种时长字段。
- 列表封面采用统一尺寸，书名与作者、时长和日期使用相同字号。

## 影响文件

- `macOS/WeReadShelf/App/LibraryStore.swift`、`macOS/WeReadShelf/App/WeReadAPI.swift`
- `iOS/bookworm/App/LibraryView.swift`

## 预估代码行数

约 70–110 行 Swift。

## 验证重点

覆盖第 5 本以后的图书和两个列表重叠时的去重，检查不同封面比例和列表字体。构建并安装 iPhone 版。
