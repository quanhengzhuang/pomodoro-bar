# CloudKit 全量数据同步

## 目标

使用 CloudKit Private Database 在 macOS 与 iOS 间同步番茄记录和每日指引，保留原 JSON 数据且不删除。

## 改动

- 新增共用 CloudKit 数据层，以单条记录和单日指引为同步单位。
- 为 macOS 和 iOS 配置同一 CloudKit Container 及必要权限。
- 首次启用时合并旧 JSON 与 CloudKit 数据，去重后上传，迁移可重复执行。
- 保留原 `records.json` 和 `daily-guidance.json`，迁移前额外备份，后续作为本地可读备份。
- 增加离线缓存、前台刷新、合并去重、写入冲突重试和错误提示。
- 补充 CloudKit Schema 部署与旧数据恢复说明。

## 影响文件

- `Sources/main.swift`
- `scripts/build.sh`
- `Packaging/`
- `iOS/DailyGuidance/DailyGuidance/PomodoroStore.swift`
- `iOS/DailyGuidance/DailyGuidance/GuidanceStore.swift`
- `iOS/DailyGuidance/DailyGuidance/DailyGuidance.entitlements`
- `iOS/DailyGuidance/DailyGuidance.xcodeproj/project.pbxproj`
- `iOS/DailyGuidance/Shared/`
- `README.md`
- `docs/en/README.md`
- `docs/cloudkit-setup.md`
- `docs/en/cloudkit-setup.md`
- `docs/code-reading-guide.md`
- `docs/en/code-reading-guide.md`

## 预估代码行数

约 500–700 行。

## 说明

- “所有数据”指已完成的番茄记录和每日指引；正在运行的计时、Live Activity 状态和设备级偏好仍留在本机，避免两台设备互相接管计时。
- 新记录使用稳定 UUID，旧记录使用现有组合字段生成兼容 ID，不改变旧 JSON 语义。
- macOS 版目前是脚本直接编译的 App；CloudKit 要求正确的 App ID、Container、entitlements 和 Apple Development 签名。
- 不清空、不删除、不覆盖无法解析的原文件。
