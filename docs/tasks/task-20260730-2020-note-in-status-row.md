# 备注显示到状态行

## 目标

设置本段备注后，在菜单第一行状态里显示备注。

## 改动

- 菜单第一行追加当前 `sessionNote`。
- 备注为空时不显示。
- 修改备注后立即刷新菜单第一行。

## 影响文件

- `Sources/main.swift`
- `docs/tasks/task-20260730-2020-note-in-status-row.md`

## 预估代码行数

约 5 行。

## 实际变更

- 菜单状态行在时间后追加当前 `sessionNote`。
- 备注为空时不添加分隔符或占位文本。
- 保存或清空备注后复用现有菜单重建逻辑，状态行立即刷新。

## 验证结果

- `./scripts/build.sh` 构建成功。
- `git diff --check` 通过。
- 构建仅有现存的 `NSUserNotification` API 弃用警告。
