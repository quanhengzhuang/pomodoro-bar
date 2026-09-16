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
- 设置“今日指引”，支持多行、列表和加粗，打开菜单即可随时查看
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

已有本地记录会与 iCloud 记录去重合并，本地原文件不会删除。`daily-guidance.json` 按日期保存今日指引的原始 Markdown 文本，支持 `-` / `*` 无序列表、`1.` 有序列表和 `**加粗**`。
