[中文](README.md) | [English](docs/en/README.md)

<img src="docs/assets/icon.png" alt="Pomodoro Bar icon" width="148">

# Pomodoro Bar · 菜单栏番茄钟

一个轻量的 macOS 菜单栏番茄钟。

## 下载

[下载最新版本](https://github.com/quanhengzhuang/pomodoro-bar/releases/latest/download/PomodoroBar.zip)，解压后打开 `PomodoroBar.app` 即可使用。

## 预览

<img src="docs/assets/screenshot-menu.png" alt="Pomodoro Bar 菜单预览" width="35%">

## 功能

- 自由计时与番茄节奏兼备：从 `00:00` 开始计时，或使用 25 分钟专注、5/15 分钟休息
- 所有操作都在菜单栏完成：开始、暂停、继续、延长或结束，进度始终一目了然
- 展开菜单后按空格即可快速开始、暂停或继续
- 设置“今日指引”，支持多行纯文本和自动折行；编辑框与菜单展示保持相同的 520 点宽度、颜色、字体和换行位置，并可回看最近 30 个自然日的历史指引
- 为当前时段添加备注，随记录一起保存
- 专注或休息完成后通过 macOS 通知提醒
- 自动整理当天记录，展示时间段、有效时长和备注
- 无需应用账号，记录和今日指引优先保存在 iCloud Drive，iCloud 不可用时自动回退到本机

## 构建

```bash
./scripts/build.sh
```

构建产物会输出到：

```text
dist/PomodoroBar.app
```

构建并运行最新版本，同时退出已运行的旧实例：

```bash
./scripts/restart.sh
```

旧实例中尚未结束的计时会被放弃，已保存的记录不受影响。

## iOS App 与灵动岛

iOS App 工程位于：

```text
iOS/DailyGuidance/DailyGuidance.xcodeproj
```

使用完整 Xcode 打开工程，选择 `PomodoroBar` target，在 Signing & Capabilities 中选择自己的 Apple Developer Team 后即可在模拟器或 iPhone 上运行。App 最低支持 iOS 16.1。

iOS 版支持自由计时、25 分钟专注、5/15 分钟休息，以及暂停、继续、调整时长、备注和最近记录。开始计时后会创建实时活动，在锁定屏幕和支持的 iPhone 灵动岛显示剩余或已用时间；活动中“结束”为红色主操作。iOS 17 及以上可在锁定屏幕或展开的灵动岛直接暂停/继续、为倒计时增加 5 分钟或结束时段（自由计时不显示延长操作），iOS 16.1–16.x 保持只读显示。请允许通知，并确认系统“设置 > Pomodoro Bar > 实时活动”已开启。

右上角的引号按钮打开“今日指引”：页面以「2026年9月17日 星期四」格式显示日期，可修改并保存当天或最近 30 个自然日内内容非空的历史指引；进入编辑状态后只显示当前日期的编辑卡片。编辑和展示使用相同的暖黄色斜体、字号、行距、边距与换行宽度。首次使用时，在系统文件选择器中进入 `iCloud Drive/PomodoroBar/` 并选择 `daily-guidance.json`；保存只更新所选日期并保留其他日期。iOS 计时记录保存在 App 自己的沙盒中，不覆盖或删除 Mac 端数据。

## 记录格式

```json
[
  {
    "date" : "2026-07-28",
    "startedAt" : "2026-07-28 15:49:45",
    "endedAt" : "2026-07-28 16:14:45",
    "durationSeconds" : 1500,
    "durationMinutes" : 25,
    "type" : "focus",
    "note" : "写周报"
  }
]
```

`type` 取值：

- `focus`
- `short_break`
- `long_break`
- `count_up`

## 数据位置

`records.json` 和 `daily-guidance.json` 默认保存在：

```text
~/Library/Mobile Documents/com~apple~CloudDocs/PomodoroBar/
```

iCloud Drive 不可用或无法写入时，应用回退到：

```text
~/.pomodoro-status-bar/
```

已有本地记录会与 iCloud 记录去重合并，本地原文件不会删除。`daily-guidance.json` 按日期保存今日指引的纯文本内容。
