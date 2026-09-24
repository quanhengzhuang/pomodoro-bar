# 修复锁屏快捷控制并统一番茄图标

## 目标

让锁屏底部的“打开 Pomodoro”快捷控制可正常打开 App，并与实时活动中的番茄图标保持一致。

## 改动

- 排查并修正快捷控制的打开动作，使主 App 和扩展都能识别；点击仍只打开 App，不开始计时。
- 将通用计时图标替换为实时活动的番茄造型，按锁屏控制的图标限制适配显示。
- 检查安装后的控制选择器、锁屏点击与 iOS 构建。

## 影响文件

- `iOS/Pomodoro/PomodoroLiveActivity/PomodoroLockScreenControl.swift`
- `iOS/Pomodoro/PomodoroLiveActivity/PomodoroLiveActivity.swift`（如需复用番茄图形）
- `iOS/Pomodoro/Pomodoro.xcodeproj/project.pbxproj`（如需将动作编入主 App 或添加图标资源）
- 可能新增主 App 与扩展共享的动作文件或扩展图标资源

## 预估代码行数

约 30–70 行 Swift 和工程配置；不改计时或记录格式。

## 验证重点

现有打开动作只出现在扩展的 Intent 元数据中，主 App 元数据中缺失；需确认修复后两边均可识别，并尽可能在 iOS 18+ 模拟器验证点击确实打开 App。
