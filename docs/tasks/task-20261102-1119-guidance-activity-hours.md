# 每日指引打开与编写活动

## 目标

记录打开、编写每日指引的行为；在每个可见日期的指引下方，用 24 个小时方块展示当天的活动。

## 改动

- Mac 每次打开含指引的主菜单、iPhone 每次进入指引页面时记录一条“打开”；自动刷新不计入。
- 仅当指引内容发生变化且保存成功时记录一条“编写”；取消、未修改和保存失败不计入。
- 新增独立、可读的 `guidance-activity.json`，逐条保存行为类型和发生时间；按行为发生的本地日期/小时汇总，编写优先于打开，同一小时无行为保持空白。
- 在 Mac 的今日指引及历史指引、iPhone 的今日卡片及日期时间流的指引下方显示一排 00–23 点方块：浅色为打开、深色为编写；提供小时和图例/辅助功能描述。

## 影响文件

- `Sources/main.swift`
- `Sources/GuidanceActivityLog.swift`
- `iOS/Pomodoro/Pomodoro/GuidanceStore.swift`
- `iOS/Pomodoro/Pomodoro/ContentView.swift`
- `iOS/Pomodoro/Pomodoro.xcodeproj/project.pbxproj`
- `scripts/build.sh`
- `Tests/GuidanceActivityLogTests.swift`
- `README.md`、`docs/en/README.md`
- 本任务中英文文档

## 预估代码行数

约 220–350 行 Swift 增删。

## 数据与验证重点

不改变或覆盖现有 `daily-guidance.json`。活动日志先按设备分别保存在本机（Mac 的 `~/.pomodoro-status-bar/`、iPhone 的 App 容器），不通过 CloudKit/iCloud Drive 合并；缺失日志按空活动显示。检查跨日、同小时“编写”覆盖“打开”、保存失败及 24 小时布局。

## 结果

已完成：Mac 主菜单和 iPhone 指引页面记录打开，内容变化且成功保存时记录编写；今日和历史指引下方展示 24 小时活动。未修改原指引 JSON，损坏的活动日志不会被覆盖。共享日志的跨日、同小时优先级、可读 JSON 和损坏文件保护测试通过；Mac 构建及通用 iOS 无签名构建通过。
