# 修复实时活动扩展安装失败

## 目标

为 `PomodoroLiveActivity.appex` 补齐有效的 `CFBundleExecutable`，修复真机安装失败。

## 改动

在实时活动扩展的 `Info.plist` 中声明由构建产物名称展开的 `CFBundleExecutable`，并重新执行 iOS 工程构建验证生成的 plist。

## 影响文件

- `iOS/DailyGuidance/PomodoroLiveActivity/Info.plist`
- `docs/tasks/task-20260917-1055-fix-live-activity-bundle-executable.md`
- `docs/en/tasks/task-20260917-1055-fix-live-activity-bundle-executable.md`

## 预估代码行数

约 1 行配置。

## 验证重点

- 生成的 `PomodoroLiveActivity.appex/Info.plist` 包含与实际二进制一致的 `CFBundleExecutable`。
- iOS 真机构建不再因 `MissingBundleExecutable` 失败。

## 实际变更

- 在实时活动扩展的 `Info.plist` 中增加 `CFBundleExecutable = $(EXECUTABLE_NAME)`。

## 验证结果

- 面向已连接 iPhone 的签名构建成功，生成的 `CFBundleExecutable` 为 `PomodoroLiveActivity`，且同名可执行文件存在。
- Xcode 完成主 App 与嵌入扩展验证；修复后的 `PomodoroBar.app` 已成功安装到真机，不再出现 `MissingBundleExecutable`。
