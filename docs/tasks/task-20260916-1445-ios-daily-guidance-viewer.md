# iOS 今日指引查看器

## 目标

新增一个简单的 iOS App，通过 iCloud Drive 中现有的 `daily-guidance.json` 查看当天的今日指引。

## 改动

- 在仓库内新增独立 SwiftUI iOS 工程，应用名称为“今日指引”，最低支持 iOS 16。
- 首次打开时通过系统文件选择器选择 `iCloud Drive/PomodoroBar/daily-guidance.json`，保存访问授权并在后续启动时自动读取。
- 按本地日期读取当天内容，以暖黄色斜体纯文本展示，支持多行、自动折行和滚动。
- 提供刷新和重新选择文件入口，并为未选择文件、当天无内容、文件不可读和 JSON 无效提供明确状态。
- App 只读 JSON，不修改、迁移或删除 Mac 端数据；复用现有应用图标作为 iOS 图标来源。
- 同步更新中英文 README，说明工程位置、数据选择和真机签名方式。

## 影响文件

- `iOS/DailyGuidance/DailyGuidance.xcodeproj/project.pbxproj`
- `iOS/DailyGuidance/DailyGuidance/`
- `.gitignore`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260916-1445-ios-daily-guidance-viewer.md`
- `docs/en/tasks/task-20260916-1445-ios-daily-guidance-viewer.md`

## 预估代码行数

约 250–350 行 Swift、工程配置和少量文档调整。

## 验证重点

- 当前环境已安装完整 Xcode，但没有 iOS 模拟器运行时；可完成源码类型检查，完整 App 构建会在资源编译阶段受此环境限制。
- 真机安装需要用户在 Xcode 中选择自己的 Apple Developer Team；不需要修改现有 iCloud 数据格式。

## 实际变更

- 新增独立的 SwiftUI iPhone 工程，首次启动可从系统文件选择器选择 `daily-guidance.json`，并保存访问授权。
- 按本地日期只读当天指引，使用暖黄色斜体纯文本展示，支持多行、自动折行、滚动和文本选择。
- 增加刷新、下拉刷新和重新选择文件入口，并覆盖未选择、加载、当天为空、文件不可读和 JSON 无效状态。
- 复用番茄图标并生成完整 iPhone App Icon 尺寸；中英文 README 已同步使用与签名说明。

## 验证结果

- Swift 源码已通过 iPhoneOS SDK 类型检查；Xcode 工程、共享 Scheme、资源目录 JSON、图标尺寸及透明通道检查均通过。
- `./scripts/build.sh` 构建成功，仅有既有通知 API deprecated 警告。
- 通用 iPhone Xcode 构建已执行，Swift 编译可正常启动；本机未安装 iOS Simulator runtime，资源编译器因此报错，未完成最终 App 打包。
