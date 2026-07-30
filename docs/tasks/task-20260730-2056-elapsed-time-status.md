[中文](task-20260730-2056-elapsed-time-status.md) | [English](task-20260730-2056-elapsed-time-status.en.md)

# 状态行统一显示已过时间

## 目标

无论正计时还是倒计时，菜单第一行都显示本段已过时间。

## 改动

- 正计时直接显示当前累计时间。
- 倒计时显示计划时长减去剩余时间；未开始时显示 `00:00`。
- 暂停期间已过时间保持不变，菜单栏本体的倒计时显示保持现状。
- 完成后更新中英文 TODO。

## 影响文件

- `Sources/main.swift`
- `docs/TODO.md`
- `docs/TODO.en.md`
- `docs/tasks/task-20260730-2056-elapsed-time-status.md`
- `docs/tasks/task-20260730-2056-elapsed-time-status.en.md`

## 预估代码行数

约 8 行代码及少量文档。

## 实际变更

- 菜单第一行在正计时中显示当前累计时间。
- 倒计时活动期间显示计划时长减去剩余时间，未开始时显示 `00:00`。
- 暂停时计时器不推进，因此第一行的已过时间保持不变。
- 菜单栏本体继续显示原有的正计时累计时间或倒计时剩余时间。
- 新增中英文 TODO 切换链接并同步任务状态。

## 验证结果

- `./scripts/build.sh` 构建成功。
- `git diff --check` 通过。
- 构建仅有现存的 `NSUserNotification` API 弃用警告。
