# CloudKit 仅同步计时记录

## 目标

让 CloudKit 只存储 Pomodoro 计时记录，每日指引继续只通过现有 JSON 文件保存和读取。

## 改动

- 移除每日指引的 CloudKit 读取、合并和写入逻辑。
- 保留每日指引 JSON 文件及其本地/iCloud Drive 回退机制。
- 保留计时记录的 CloudKit 同步与现有数据兼容逻辑。
- 更新相关 CloudKit 文档，明确每日指引不进入 CloudKit。

## 影响文件

- `Sources/main.swift`
- `iOS/DailyGuidance/Shared/PomodoroCloudKitStore.swift`
- `docs/cloudkit-setup.md`
- `docs/en/cloudkit-setup.md`

## 预估代码行数

约 40–70 行。

## 结果

已完成。CloudKit 现在只读写 `PomodoroSession`；每日指引仅通过 `daily-guidance.json` 及其 iCloud Drive/本地回退副本保存。`./scripts/build.sh` 构建通过；iOS 工程因当前环境未安装完整 Xcode，无法运行 `xcodebuild` 验证。
