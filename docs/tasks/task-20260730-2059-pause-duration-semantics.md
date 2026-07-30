# 暂停不计入本段时长

## 目标

记录和番茄外时间统一使用有效计时时长，暂停时间不计入本段并归入番茄外时间。

## 改动

- 记录新增 `durationSeconds`，保存不含暂停的秒级有效时长，同时保留 `durationMinutes`。
- 菜单记录时长改用 `durationSeconds`，不再通过 `endedAt - startedAt` 推导。
- 番茄外时间改为墙上经过时间减去有效计时时长，使暂停时间计入番茄外时间。
- 完成后更新 README 和中英文 TODO。

## 影响文件

- `Sources/main.swift`
- `README.md`
- `docs/en/README.md`
- `docs/TODO.md`
- `docs/en/TODO.md`
- `docs/tasks/task-20260730-2059-pause-duration-semantics.md`
- `docs/en/tasks/task-20260730-2059-pause-duration-semantics.md`

## 预估代码行数

约 45 行代码及少量文档。

## 数据兼容

- 旧记录缺少 `durationSeconds` 时使用 `durationMinutes × 60`，不删除或覆盖其他字段。
- JSON 继续保留可读的 `durationMinutes`，新记录额外保存精确秒数。

## 实际变更

- `PomodoroRecord` 新增 `durationSeconds`；新记录保存不含暂停的实际计时秒数，并同步生成 `durationMinutes`。
- 旧记录解码时缺少秒数字段会回退到分钟数，后续保存时补齐新字段。
- 菜单记录时长统一读取有效计时秒数，不再使用开始时间减结束时间。
- 番茄外时间从首段开始至当前的墙上时间中减去历史和当前的有效计时，因此暂停自动归入番茄外时间。
- README 的中英文 JSON 示例与 TODO 已同步更新。

## 验证结果

- `./scripts/build.sh` 构建成功。
- `git diff --check` 通过。
- 构建仅有现存的 `NSUserNotification` API 弃用警告。
