# 移除 Mac 端每日指引活动

## 目标

Mac 端不再记录或展示每日指引的打开/编写活动，iPhone 端继续保留 24 小时活动方块和本机活动日志。

## 改动

- 移除 Mac 端活动日志加载、写入和 `guidance-activity.json` 路径。
- 移除 Mac 今日指引与历史指引下方的 24 小时活动方块。
- 保留 iPhone 端活动日志、活动方块、数据格式和既有 `daily-guidance.json`。
- 更新中英文 README 与任务说明。

## 影响文件

- `Sources/main.swift`
- `Sources/GuidanceActivityLog.swift`
- `README.md`
- `docs/en/README.md`
- 本任务中英文文档

## 预估代码行数

约 70–110 行删除及文档调整。

## 验证重点

Mac 构建后菜单不再出现活动条，iPhone 端仍能编译并显示活动条；不修改 `daily-guidance.json` 和 iPhone 活动日志。

## 结果

已完成。Mac 端已移除活动日志读写和菜单活动条；iPhone 端继续保留活动日志与 24 小时方块。旧 Mac 活动日志文件不读取、不写入、不删除，既有指引正文 JSON 不变。
