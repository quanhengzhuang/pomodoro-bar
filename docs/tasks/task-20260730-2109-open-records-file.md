# 用打开记录文件替代清空记录

## 目标

移除危险的“清空记录”，提供安全的 `records.json` 打开入口。

## 改动

- 删除清空记录菜单、确认弹窗和清空前备份逻辑。
- 新增“打开记录文件...”菜单，使用默认应用打开 `records.json`。
- 文件不存在时先创建可读的空 JSON。
- 更新中英文 README 和 TODO。

## 影响文件

- `Sources/main.swift`
- `README.md`
- `docs/en/README.md`
- `docs/TODO.md`
- `docs/en/TODO.md`
- `docs/tasks/task-20260730-2109-open-records-file.md`
- `docs/en/tasks/task-20260730-2109-open-records-file.md`

## 预估代码行数

删除约 55 行，新增约 10 行代码及少量文档。

## 实际变更

- 删除“清空记录”菜单、确认弹窗、备份提示及对应备份函数。
- 菜单新增“打开记录文件...”，由默认应用打开 `records.json`。
- 没有记录文件时先通过现有保存逻辑生成可读的 `[]` JSON。
- 打开失败时显示包含完整文件路径的错误提示。
- 中英文 README 和 TODO 已同步更新。

## 验证结果

- 源码中已无清空记录或清空前备份入口。
- `./scripts/build.sh` 构建成功。
- `git diff --check` 通过。
- 构建仅有现存的 `NSUserNotification` API 弃用警告。
