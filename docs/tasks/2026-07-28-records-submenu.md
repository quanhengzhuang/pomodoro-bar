# 记录恢复为子菜单

## 目标

退回 popover 试验，恢复子菜单版本。

## 改动

- 主菜单显示最近 10 条记录。
- 子菜单显示当天全部记录。
- 记录时间段使用等宽字体。

## 影响文件

- `Sources/main.swift`
- `docs/tasks/2026-07-28-records-submenu.md`

## 预估代码行数

约 40 行。

## 实际

已退回子菜单方案；主菜单显示最近 10 条，全部记录子菜单显示当天全部记录，整行记录使用 Monaco 字体。`./scripts/build.sh` 通过，只有既有通知 API deprecated 警告。
