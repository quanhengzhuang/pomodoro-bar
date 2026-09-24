# 添加 iOS 锁屏快捷控制

## 目标

让 Pomodoro 出现在 iOS 18 及以上锁屏底部的快捷控制选择器中。

## 改动

- 在现有 Widget 扩展中添加带番茄钟图标的快捷控制；默认点击后打开主 App。
- 保留现有实时活动及 iOS 16.1–17 的行为，不改变计时状态和记录格式。
- 在中英文 README 说明系统版本要求及添加方法。

## 影响文件

- `iOS/Pomodoro/PomodoroLiveActivity/` 中的 Widget 定义与注册文件
- `iOS/Pomodoro/Pomodoro.xcodeproj/project.pbxproj`
- `README.md`、`docs/en/README.md`

## 预估代码行数

约 25–50 行 Swift 和工程配置；文档约 6 行。

## 验证重点

验证 iOS 构建和锁屏快捷控制可添加；实际锁屏显示与点击行为需在 iOS 18+ 设备或模拟器确认。
