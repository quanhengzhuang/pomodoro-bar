[中文](README.md) | [English](docs/en/README.md)

<img src="docs/assets/icon.png" alt="Pomodoro Bar icon" width="148">

# Pomodoro Bar · 菜单栏番茄钟

一个轻量的 macOS 菜单栏番茄钟。

## 预览

<img src="docs/assets/screenshot-menu.png" alt="Pomodoro Bar 菜单预览" width="35%">

## 功能

- 菜单栏显示番茄图标、倒计时和暂停状态
- 支持从 `00:00` 开始的正计时
- 支持专注、短休息、长休息
- 支持自定义专注时长
- 点击模式菜单即可切换并开始
- 菜单展开时，按空格开始或暂停
- 完成后发送 macOS 通知中心提醒
- 记录当天全部番茄和休息段
- 记录保存为可读 JSON：`~/.pomodoro-status-bar/records.json`
- 清空记录前自动备份

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
