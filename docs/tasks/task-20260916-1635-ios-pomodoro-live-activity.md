# iOS 番茄钟与灵动岛

## 目标

将现有 iOS 查看器扩展为完整的 Pomodoro Bar iOS App，并通过实时活动在灵动岛和锁定屏幕持续显示计时。

## 改动

- 将现有 SwiftUI iOS 工程升级并更名为“Pomodoro Bar”，保留今日指引的文件选择、读取和现有未提交授权修复。
- 实现自由计时、25 分钟专注、5/15 分钟休息，以及开始、暂停、继续、调整倒计时、备注和结束操作；用绝对时间计算进度并恢复未结束时段。
- 以番茄切片式进度环作为主界面视觉，展示当前模式、时间、今日累计和最近记录，并适配深色模式、动态字体与辅助功能。
- 新增 ActivityKit/WidgetKit 实时活动，在灵动岛的紧凑、最小和展开状态及锁定屏幕显示倒计时或正计时；开始、暂停、继续、调整和结束时同步更新或关闭。
- 完成时发送本地通知；记录沿用现有可读 JSON 字段与时长语义，iOS 侧使用独立沙盒文件，不修改或删除 Mac 端数据。
- 将最低系统版本调整为 iOS 16.1，补充实时活动、通知和 Widget Extension 配置，并同步更新中英文 README。

## 影响文件

- `iOS/DailyGuidance/DailyGuidance.xcodeproj/project.pbxproj`
- `iOS/DailyGuidance/DailyGuidance/`
- `iOS/DailyGuidance/PomodoroLiveActivity/`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260916-1635-ios-pomodoro-live-activity.md`
- `docs/en/tasks/task-20260916-1635-ios-pomodoro-live-activity.md`

## 预估代码行数

约 700–1,000 行 Swift、工程配置和少量文档调整。

## 兼容与验证重点

- 保持现有 `records.json` 字段、类型和秒级时长语义；不迁移、不覆盖 Mac 端记录或今日指引数据。
- 验证前后台切换、进程重启、跨零点、暂停恢复、倒计时完成、实时活动生命周期，以及无灵动岛设备的锁定屏幕展示。
- 使用现有开发团队配置进行真机构建；灵动岛最终效果需要支持灵动岛的真机验证。

## 实际变更

- 将 iOS target 升级为 Pomodoro Bar，新增番茄切片进度环、四种计时模式、开始/暂停/继续/结束、时长调整、备注、今日汇总和最近记录。
- 计时使用绝对时间与累计暂停时长计算；活动时段会写入 `UserDefaults` 并在重启后恢复，记录以现有字段写入 iOS App 独立沙盒中的可读 JSON。
- 新增 Widget Extension 和 ActivityKit 实时活动，覆盖锁定屏幕以及灵动岛最小、紧凑和展开状态；暂停、继续、调时和结束均会同步状态。
- 倒计时运行时预先安排本地完成通知，暂停或手动结束时取消；前台也可显示通知横幅。
- 保留今日指引入口及只读文件授权逻辑，并将最低系统版本调整为 iOS 16.1、启用实时活动配置、同步中英文 README。

## 验证结果

- 主 App 和实时活动 Extension 均通过 iPhoneOS 16.1 目标的 Swift 类型检查；Xcode 工程和 Extension `Info.plist` 通过格式检查。
- Xcode 正确识别 `PomodoroBar` 与 `PomodoroLiveActivity` 两个 target，Extension Swift 编译可正常完成。
- `./scripts/build.sh` 构建 macOS App 成功，仅保留既有通知 API 弃用警告。
- 通用 iPhone 构建已执行；当前机器没有可用的 iOS Simulator runtime，资源编译器因此停止最终打包。灵动岛布局与签名安装仍需在支持灵动岛的真机上最终确认。
