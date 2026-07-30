# 不足 5 分钟结束确认

## 目标

不足 5 分钟结束时不要直接结束，先让用户确认或取消。

## 改动

- 点击「结束」且有效时长不足 5 分钟时弹出确认提醒。
- 选择确认：结束本段，不写入记录。
- 选择取消：继续保留当前计时状态。
- 超过 5 分钟仍按现有逻辑记录并结束。
- 完成后勾选 TODO。

## 影响文件

- `Sources/main.swift`
- `TODO.md`
- `docs/en/TODO.md`
- `docs/tasks/task-20260730-2158-confirm-short-session-end.md`
- `docs/en/tasks/task-20260730-2158-confirm-short-session-end.md`

## 预估代码行数

约 25 行。

## 实际

已实现；不足 5 分钟时先确认，取消会保留当前计时状态，确认才结束且不记录。`./scripts/build.sh` 通过。
