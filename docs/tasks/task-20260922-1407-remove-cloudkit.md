# 回退 CloudKit 集成

## 目标

恢复到引入 CloudKit 前的存储与同步方式，不再要求开发者证书来使用计时和每日指引。

## 改动

- 撤销 CloudKit 集成及其后续调整，恢复 Mac 的 JSON/iCloud Drive 记录与指引流程，以及 iOS 原有的计时记录和指引文件流程。
- 移除 CloudKit 专用代码、签名权限与构建配置；更新中英文说明，保留历史任务文档。
- 不删除或清空现有 JSON；核对新版本留下的本地 JSON 是否需要兼容读取，避免回退时丢失记录。

## 影响文件

- `Sources/main.swift`、`scripts/build.sh`、`Packaging/PomodoroBar.entitlements`
- `iOS/DailyGuidance/` 中的 Store、界面、工程设置与共享 CloudKit 文件
- `README.md`、`docs/en/README.md`、中英文代码阅读指南及 CloudKit 配置说明
- 本任务中英文文档

## 预估代码行数

约 800–1,300 行增删，以撤销集成改动为主。

## 结果

已完成。代码与构建配置已恢复到引入 CloudKit 前的状态，计时记录和每日指引继续使用 JSON/iCloud Drive 或本地回退目录；`./scripts/build.sh` 构建通过。CloudKit 历史任务文档保留为历史记录，但不再属于当前代码流程。
