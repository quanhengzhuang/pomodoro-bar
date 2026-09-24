# iOS Xcode 工程更名

## 目标

将 iOS Xcode 工程 `DailyGuidance.xcodeproj` 更名为 `Pomodoro.xcodeproj`，与当前 Mac 应用名称一致。

## 改动

- 更名工程包并更新共享 scheme 对工程的引用、工程配置名称和中英文 README 路径。
- 保留现有 `PomodoroBar` target、Bundle Identifier、App Group 及 `DailyGuidance` 源码目录，避免影响应用安装和现有数据。
- 检查工程文件引用、构建脚本及工程结构。

## 影响文件

- `iOS/DailyGuidance/DailyGuidance.xcodeproj/` → `iOS/DailyGuidance/Pomodoro.xcodeproj/`
- `README.md`、`docs/en/README.md`
- 本任务中英文文档

## 预估代码行数

约 10–25 行，加上工程目录更名。

## 结果

已将 Xcode 工程改为 `iOS/DailyGuidance/Pomodoro.xcodeproj`，并同步共享 scheme、工程配置显示名称及两份 README。`xcodebuild -list` 识别工程名 `Pomodoro`、原有两个 target 和两个 scheme；工程文件与 scheme 格式检查通过，`./scripts/build.sh` 通过。Bundle Identifier、App Group 和数据目录未改。
