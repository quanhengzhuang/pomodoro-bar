# 修复锁屏快捷控制图标

## 目标

修复锁屏快捷控制显示问号的问题，让它稳定显示番茄图标。

## 改动

- 将快捷控制中的自定义 SwiftUI 图形替换为 WidgetKit 可识别的静态图标资源。
- 保持图标使用实时活动番茄的红色、橙色环线和绿色叶子视觉元素。
- 不修改快捷控制的打开动作、计时逻辑和记录数据。

## 影响文件

- `iOS/Pomodoro/PomodoroLiveActivity/PomodoroLockScreenControl.swift`
- `iOS/Pomodoro/PomodoroLiveActivity/Assets.xcassets/`
- `iOS/Pomodoro/Pomodoro.xcodeproj/project.pbxproj`

## 预估代码行数

约 10–30 行 Swift 和工程配置，新增一组图标资源。

## 验证重点

确认快捷控制不再显示问号，重新添加后能显示番茄图标，并保持点击打开 App 的行为。
