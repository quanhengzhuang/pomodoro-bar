# iOS 今日指引历史

## 目标

让 iOS 版可以查看最近 30 个自然日的今日指引。

## 改动

- 在今日指引页面增加历史入口，按日期倒序显示最近 30 个自然日内内容非空的记录。
- 列表显示日期和星期；进入详情后沿用暖黄色斜体纯文本样式，支持多行、自动折行和滚动。
- 继续只读现有 `daily-guidance.json`，不修改数据格式、路径或历史内容。
- 同步更新中英文 README。

## 影响文件

- `iOS/DailyGuidance/DailyGuidance/GuidanceStore.swift`
- `iOS/DailyGuidance/DailyGuidance/ContentView.swift`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260917-1240-ios-daily-guidance-history.md`
- `docs/en/tasks/task-20260917-1240-ios-daily-guidance-history.md`

## 预估代码行数

约 100–160 行 Swift 和文档调整。

## 验证重点

- 今天及前几天的测试数据按日期倒序显示，并排除空内容和 30 天之外的数据。
- 文件权限失效、文件不存在或 JSON 无效时，保留现有明确提示。
- iOS 源码检查、Mac 版构建和提交前状态检查通过。

## 实际变更

- 今日指引页新增日历入口，展示最近 30 个自然日内内容非空的记录，并按日期倒序排列。
- 历史列表显示日期和星期，详情沿用暖黄色斜体纯文本视图，支持多行、自动折行、滚动和文本选择。
- 继续只读原有 `daily-guidance.json`，未修改数据格式、路径或已有内容。
- 中英文 README 已同步 iOS 历史查看说明。

## 验证结果

- iOS 主 App 的 Swift 源码通过 iPhoneOS SDK 类型检查。
- `./scripts/build.sh` 构建成功，仅有既有通知 API 弃用警告；`git diff --check` 通过。
- 通用 iPhone 构建已执行并进入 Swift 编译；当前机器没有可用的 iOS Simulator runtime，资源编译器因此中止最终打包。
