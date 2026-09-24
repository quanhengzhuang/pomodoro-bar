# Mac 项目去掉 Bar 命名

## 目标

将 Mac 项目和构建产物名称从 `PomodoroBar` 统一改为 `Pomodoro`，去掉 `Bar`，同时保持 Bundle Identifier、状态栏实例标识和已有数据目录兼容。

## 改动

- 更新 Mac 构建脚本、Info.plist、重启脚本和相关 README/文档中的项目与产物名称。
- 保留 `local.codex.PomodoroBar`、`PomodoroBar` 数据目录和进程兼容逻辑，避免影响已有安装与数据。
- 构建并检查新产物名称；不提交 `dist/` 或 `.build/`。

## 影响文件

- `scripts/build.sh`
- `scripts/restart.sh`
- `Packaging/Info.plist`
- `README.md`、`docs/en/README.md`、相关双语文档

## 预估代码行数

约 20–40 行。

## 结果

已将 Mac 构建产物和显示名称改为 `Pomodoro.app` / `Pomodoro`；旧 Bundle Identifier 和 `PomodoroBar` 数据目录保持不变。`./scripts/build.sh` 与脚本语法检查通过，已核对新包的可执行文件、显示名称及 Bundle Identifier；旧版 `dist/PomodoroBar.app` 未删除。
