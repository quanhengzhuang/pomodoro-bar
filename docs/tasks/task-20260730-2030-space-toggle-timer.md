# 空格开始或暂停计时

## 目标

菜单展开时，只按空格即可开始、暂停或继续当前计时。

## 改动

- 为开始/暂停菜单项保留空格快捷键，并显式移除 Command 等修饰键。
- 在 README 补充空格快捷键说明，并将对应 TODO 标记为完成。

## 影响文件

- `Sources/main.swift`
- `README.md`
- `docs/TODO.md`
- `docs/tasks/task-20260730-2030-space-toggle-timer.md`

## 预估代码行数

约 1 行代码及少量文档。

## 实际变更

- `startPauseMenuItem` 使用空格作为 `keyEquivalent`，并将 `keyEquivalentModifierMask` 设为空。
- 空格触发现有 `toggleTimer()`，未开始时开始、运行中暂停、暂停后继续。
- README 已补充使用方式，对应 TODO 已标记完成。

## 验证结果

- `./scripts/build.sh` 构建成功，产物为 `dist/PomodoroBar.app`。
- `git diff --check` 通过。
- 构建仅有现存的 `NSUserNotification` API 弃用警告。
