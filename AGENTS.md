# AGENTS.md

## 开发流程

- 非平凡改动先写 task，再等用户确认后编码。
- task 放在 `docs/tasks/YYYY-MM-DD-xxxxxx.md`。
- task 保持极简，固定包含：目标、改动、影响文件、预估代码行数。
- 只在确实涉及数据、兼容、风险或验证重点时额外补充说明。
- 实现后简单补充实际变更和验证结果。
- 小修复可跳过 task，但要说明原因。

## 数据兼容

- 记录文件：`~/.pomodoro-status-bar/records.json`。
- 涉及记录格式、路径、时长语义、清空或迁移时，必须兼容旧数据。
- 不删除用户数据；破坏性操作前先备份。
- JSON 保持可读。

## 构建与提交

- 源码或打包配置变更后运行 `./scripts/build.sh`。
- 不提交 `dist/` 或 `.build/`。
- 提交前检查 `git status --short --branch`。
