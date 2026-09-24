# 重命名 iOS 源码目录

## 目标

将 iOS 代码目录中的 `DailyGuidance` 改为 `Pomodoro`，与 Xcode 工程名称保持一致。

## 改动

- 将 `iOS/DailyGuidance/` 重命名为 `iOS/Pomodoro/`，内部主 App 源码目录也从 `DailyGuidance/` 改为 `Pomodoro/`。
- 更新 Xcode 工程中的源码组路径、资源路径、签名配置和相关文档引用。
- 保持 Swift 文件名、类型名、Bundle Identifier、数据文件路径和运行逻辑不变。

## 影响文件

- `iOS/Pomodoro/`
- `iOS/Pomodoro/Pomodoro.xcodeproj/project.pbxproj`
- `README.md`
- `docs/code-reading-guide.md`
- 对应英文文档

## 预估代码行数

逻辑代码 0 行；路径和工程配置约 20 行。
