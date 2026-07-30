# 所有文档提供中英文版本

## 目标

为仓库内所有 Markdown 文档提供中文和英文版本。

## 改动

- 保留现有中文文件路径，在 `docs/en/` 下按相同结构存放英文文件。
- 仅在中英文 README 中添加语言切换链接。
- 移动现有 `docs/TODO.en.md` 和 `docs/tasks/*.en.md` 到新目录结构。
- 翻译现有内容，保持命令、路径、代码块和技术语义一致。
- 完成后更新中英文 TODO。

## 影响文件

- `README.md`、`docs/en/README.md`
- `AGENTS.md`、`docs/en/AGENTS.md`
- `docs/TODO.md`、`docs/en/TODO.md`
- `docs/tasks/*.md`、`docs/en/tasks/*.md`
- `docs/tasks/task-20260730-2055-bilingual-documentation.md`
- `docs/en/tasks/task-20260730-2055-bilingual-documentation.md`

## 预估代码行数

0 行代码，约 650 行文档。

## 实际变更

- 中文文档保留原路径，英文文档按相同结构放入 `docs/en/`。
- 中英文 README 添加相互切换链接；AGENTS、TODO 和 task 不添加语言链接。
- 旧的 `docs/TODO.en.md` 和 `docs/tasks/*.en.md` 已迁移到新目录。
- 所有命令、路径、代码块和任务状态均在英文版本中保持一致。

## 验证结果

- 每份中文 Markdown 文档都有对应的 `docs/en/` 英文文件。
- 仓库中只有中英文 README 包含语言切换链接。
- `git diff --check` 通过。
