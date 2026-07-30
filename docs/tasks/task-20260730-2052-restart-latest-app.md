# 自动重启到最新版本

## 目标

运行新构建版本时，自动退出相同 Bundle ID 的旧实例并启动新实例。

## 改动

- 新增 `scripts/restart.sh`，先构建，再通过 `open -n` 强制启动新实例。
- 新实例启动时按 `local.codex.PomodoroBar` 查找并正常退出其他实例。
- README 补充重启运行命令，完成后更新 TODO。

## 影响文件

- `Sources/main.swift`
- `scripts/restart.sh`
- `README.md`
- `docs/TODO.md`
- `docs/tasks/task-20260730-2052-restart-latest-app.md`

## 预估代码行数

约 35 行代码及少量文档。

## 风险

- 旧实例中尚未结束的计时不会写入记录；已保存的 `records.json` 不受影响。
- 普通双击可能只激活旧实例，因此自动替换流程以 `scripts/restart.sh` 为准。

## 实际变更

- 新实例启动时通过 `NSRunningApplication` 查找相同 Bundle ID 的其他进程并请求其正常退出。
- 新增可执行的 `scripts/restart.sh`，复用现有构建脚本后通过 `open -n` 启动新实例。
- README 已补充重启命令和未完成计时会被放弃的说明，TODO 已标记完成。

## 验证结果

- `bash -n scripts/restart.sh` 通过。
- `./scripts/build.sh` 构建成功。
- `git diff --check` 通过。
- 为避免中断当前计时，未在验证阶段实际执行 `scripts/restart.sh`。
- 构建仅有现存的 `NSUserNotification` API 弃用警告。
