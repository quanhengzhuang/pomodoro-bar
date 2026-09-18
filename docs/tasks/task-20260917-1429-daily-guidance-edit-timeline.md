# 今日指引编辑与时间流

## 目标

让 iOS 版可以修改今日指引，并在同一页面按日期上下滑动浏览最近 30 天内容；同时让 Mac 编辑框与展示样式一致。

## 改动

- 今日指引页面显示当天日期，保持暖黄色斜体、多行和自动折行样式。
- 增加编辑入口，支持多行修改当天内容并写回当前选择的 `daily-guidance.json`。
- 将历史入口调整为上下滑动的日期时间流，按日期倒序连续展示最近 30 个自然日内的非空指引。
- 保存前保留原有 JSON 其他日期数据，写入失败时明确提示，不删除历史内容。
- Mac 编辑框与菜单展示统一为 520 点宽，并使用相同的暖黄色、斜体、字号、边距和自动换行宽度。
- 同步更新中英文 README。

## 影响文件

- `iOS/DailyGuidance/DailyGuidance/GuidanceStore.swift`
- `iOS/DailyGuidance/DailyGuidance/ContentView.swift`
- `Sources/main.swift`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260917-1429-daily-guidance-edit-timeline.md`
- `docs/en/tasks/task-20260917-1429-daily-guidance-edit-timeline.md`

## 预估代码行数

约 250–350 行 Swift 和文档调整。

## 数据与验证说明

- 沿用现有日期到纯文本的 JSON 格式和 iCloud 文件授权，不迁移或清空数据。
- 验证多行保存、重新读取、日期显示、历史滑动顺序及近 30 天过滤。
- 验证 iOS 和 Mac 编辑状态与展示状态的颜色、字体、内容宽度和换行位置一致。

## 实际变更

- iOS 今日指引改为日期时间流：当天置顶并可编辑，其他非空记录按日期倒序连续展示，可直接上下滑动浏览。
- iOS 编辑与展示复用同一文本组件，统一暖黄色斜体、字号、行距、边距和自动换行宽度；保存只更新当天并保留其他日期。
- Mac 编辑框扩展为与菜单一致的 520 点宽度，并复用相同的颜色、字体、斜体、边距和文本内容宽度。
- 中英文 README 已同步更新。

## 验证结果

- iOS 主 App Swift 源码通过 iPhoneOS SDK 类型检查。
- `./scripts/build.sh` 构建成功，仅有既有通知 API 弃用警告。
- `git diff --check` 通过；通用 iPhone 构建仍受当前机器缺少 iOS Simulator runtime 的资源编译限制。
