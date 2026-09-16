# 今日指引

## 目标

支持设置和修改当天的多行指引内容，并在菜单中清晰展示。

## 改动

- 功能命名为“今日指引”；未设置时显示“设置今日指引...”，已设置时显示内容和“修改今日指引...”。
- 使用多行文本框输入，保存空内容时清除当天内容。
- 支持轻量 Markdown：无序列表、有序列表和 `**加粗**`；列表保持缩进，长内容继续自动折行。
- `daily-guidance.json` 保存原始 Markdown 文本，不支持多级列表、标题、链接或图片。
- 将内容按日期保存为可读的 `daily-guidance.json`；菜单只读取当天内容，不删除历史日期数据。
- 将 `records.json` 和 `daily-guidance.json` 默认保存在 `~/Library/Mobile Documents/com~apple~CloudDocs/PomodoroBar/`。
- 首次使用时将现有本地记录与 iCloud 记录去重合并，保留 `~/.pomodoro-status-bar/` 中的原文件，不删除用户数据。
- iCloud Drive 不可用或无法写入时，回退到 `~/.pomodoro-status-bar/`；恢复后再合并到 iCloud。
- 在菜单顶部展示内容，限制展示宽度，保留手动换行并对过长文字自动折行。
- 在中英文 README 中补充功能说明。

## 影响文件

- `Sources/main.swift`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260916-1338-daily-guidance.md`
- `docs/en/tasks/task-20260916-1338-daily-guidance.md`

## 预估代码行数

约 240–320 行代码及少量文档调整。

## 实际变更

- 菜单顶部增加“今日指引”，支持多行编辑、自动折行、设置、修改和清除。
- 支持无序列表、有序列表和 `**加粗**` 的轻量 Markdown 展示，列表长行使用悬挂缩进。
- `records.json` 与 `daily-guidance.json` 统一优先保存到 iCloud Drive 的 `PomodoroBar` 目录。
- 自动合并本地与 iCloud 记录并去重，本地原文件保留；iCloud 不可用或文件无法读取时回退到本地，避免覆盖不可读的云端文件。
- 每次打开菜单时刷新云端数据，并在本地回退文件更新后重新合并到 iCloud。
- 中英文 README 已同步数据路径、回退规则和今日指引格式说明。

## 验证结果

- `./scripts/build.sh` 构建成功，仅有既有通知 API deprecated 警告。
- `git diff --check` 通过，源码和文档中无旧的功能名称或旧存储属性引用。
