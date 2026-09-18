# 灵动岛实时活动操作

## 目标

在灵动岛展开态和锁定屏幕实时活动中直接暂停、继续、延长或结束当前番茄时段，并与 App 状态保持一致。

## 改动

- 为主 App 与实时活动扩展配置 App Group，共享当前时段状态和操作请求；继续兼容现有 App 内会话数据。
- 新增 iOS 17+ `AppIntent` 操作：暂停/继续、倒计时增加 5 分钟、结束当前时段；自由计时不显示延长操作。
- 统一主 App、灵动岛展开态和锁定屏幕的操作层级：未开始时“开始”为番茄红主操作；开始后“结束”改为高亮红色，暂停/继续和延长使用次级样式。
- 操作后立即更新实时活动时间和状态；App 回到前台时读取共享状态，避免灵动岛与主界面不一致。
- iOS 16.1–16.x 保持现有只读实时活动展示；紧凑和最小灵动岛继续以时间显示为主。
- 同步更新中英文 README，说明系统版本和可用操作。

## 影响文件

- `iOS/DailyGuidance/DailyGuidance.xcodeproj/project.pbxproj`
- `iOS/DailyGuidance/DailyGuidance/`
- `iOS/DailyGuidance/PomodoroLiveActivity/`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260918-1027-interactive-live-activity.md`
- `docs/en/tasks/task-20260918-1027-interactive-live-activity.md`

## 预估代码行数

约 250–380 行 Swift、权限配置和少量文档调整。

## 兼容与验证重点

- 不改变现有 `records.json` 格式；结束不足 3 分钟的时段仍不写入记录，结束有效时段只写入一次。
- 验证 App 前台、后台和被系统终止时的暂停/继续、延长、结束操作，以及本地通知的重新安排与取消。
- 使用已连接的 iOS 26 真机验证锁定屏幕和灵动岛操作；检查 iOS 16.1 编译兼容与 iOS 17 可用性隔离。

## 验证结果

- 主 App 源码已按 iOS 16.1 目标完成类型检查；实时活动扩展已按 iOS 16.1 目标编译，并成功提取 iOS 17+ App Intent 元数据。
- App 与扩展的 App Group 权限文件、扩展 `Info.plist` 和 Xcode 工程文件均通过格式检查；生成的扩展包包含有效可执行文件。
- 已使用开发者签名完成通用 iPhone Debug 构建，App Group 权限成功写入主 App，实时活动扩展通过嵌入与签名验证。
- 记录中的 iPhone 当前未出现在 Xcode 可用设备列表，尚需设备重新连接后确认锁定屏幕与灵动岛上的实际交互布局。
