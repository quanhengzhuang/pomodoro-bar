# 书虫格子页短书名

## 目标

让格子页的书名更短，居中对齐封面。

## 改动

- 在常见的中英文标点处省略后面的文字，格子和格子分享图使用同一显示规则。
- 格子书名在封面正下方居中，支持单行截断。列表和真实书名沿用原值。

## 影响文件

- iOS 书虫的 LibraryView.swift 与 BookListShare.swift
- WeReadShelf 的 ReadingModels.swift

## 预估代码行数

约 20–35 行 Swift。
