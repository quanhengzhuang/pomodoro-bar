# Bookworm list metadata order

## Goal

Group list details into author, recommendation, and reading history lines, and verify the reader count's meaning.

## Changes

- Show approximate word count beside the author and reader count beside the recommendation. Show reading duration before the date.
- Use the public WeRead book page's readership statistic, verify the edition's book ID, and stop displaying the cached storefront in-progress count. [Public book example](https://weread.qq.com/web/reader/a623278071e0b2e0a622468) · [Previous field](https://github.com/Tencent/WeChatReading/blob/main/skills/search.md)
- Use the same grouping in the shared list image.

## Affected files

- iOS Bookworm's LibraryView.swift and BookListShare.swift.
- WeReadShelf's WeReadAPI.swift and LibraryStore.swift.

## Estimated code size

About 60–120 lines of Swift.
