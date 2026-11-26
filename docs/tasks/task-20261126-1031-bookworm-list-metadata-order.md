# 书虫列表信息顺序

## 目标

按作者、推荐值与阅读记录三行分组，并核对阅读人数的数据口径。

## 改动

- 作者同行显示约数形式的字数，推荐值同行显示「XXX 人阅读」，时长先于日期并显示「已读」。
- 阅读人数使用微信读书公开书页的「阅读」统计，按书籍 ID 校验，旧版书城搜索的「在读人数」缓存退出显示。[公开书页示例](https://weread.qq.com/web/reader/a623278071e0b2e0a622468) · [旧字段说明](https://github.com/Tencent/WeChatReading/blob/main/skills/search.md)
- 列表分享图沿用同样分组。

## 影响文件

- iOS 书虫的 LibraryView.swift 和 BookListShare.swift
- WeReadShelf 的 WeReadAPI.swift 与 LibraryStore.swift

## 预估代码行数

约 60–120 行 Swift。
