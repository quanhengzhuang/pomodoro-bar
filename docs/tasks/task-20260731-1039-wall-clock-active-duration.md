# 使用墙上时间计算有效时长

## 目标

没主动暂停时，正计时记录应按真实经过时间计算。

## 改动

- 不再依赖每秒 tick 累加正计时时长。
- 记录主动暂停开始时间和累计暂停秒数。
- 有效时长使用 `现在 - 开始时间 - 主动暂停时长`。
- 倒计时的显示、记录、番茄内时间也使用同一套有效时长。

## 影响文件

- `Sources/main.swift`
- `docs/tasks/task-20260731-1039-wall-clock-active-duration.md`
- `docs/en/tasks/task-20260731-1039-wall-clock-active-duration.md`

## 预估代码行数

约 45 行。

## 实际

已实现；有效时长改为 `当前时间 - 开始时间 - 主动暂停时长`，正计时不再依赖每秒 tick 累加。`./scripts/build.sh` 通过。
