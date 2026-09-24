# 源码阅读与维护指南

这份指南面向第一次接触 Swift、macOS AppKit、iOS SwiftUI 和 Live Activity 的维护者。源码中的中文注释解释局部实现；本文先说明整个工程怎样协作。

## 工程由什么组成

仓库里实际有三个运行单元：

1. **Mac 菜单栏 App**：`Sources/main.swift`
2. **iPhone 主 App**：`iOS/DailyGuidance/DailyGuidance/`
3. **锁屏实时活动扩展**：`iOS/DailyGuidance/PomodoroLiveActivity/`

Mac App 和 iPhone App 是两个独立程序。它们都能读取“今日指引”，但计时记录目前分别保存：Mac 记录优先进入 iCloud，iPhone 计时记录保存在自己的 App 沙盒。

iPhone 主 App 与实时活动扩展也是两个独立进程。它们通过 App Group 中的共享会话文件交换当前计时状态。

## 建议阅读顺序

### 第一遍：理解数据模型

依次阅读：

1. `iOS/DailyGuidance/DailyGuidance/PomodoroActivityAttributes.swift`
2. `iOS/DailyGuidance/Shared/PomodoroSharedSession.swift`
3. `iOS/DailyGuidance/DailyGuidance/GuidanceStore.swift`
4. `iOS/DailyGuidance/DailyGuidance/PomodoroStore.swift`

先弄清楚这些核心概念：

- `PomodoroMode`：当前是自由计时、专注、短休息还是长休息。
- `elapsedSeconds`：实际运行时间，不包含暂停。
- `displaySeconds`：界面显示时间；正计时等于已用时间，倒计时等于剩余时间。
- `sessionID`：一段计时的唯一身份，用于拒绝旧锁屏按钮控制新计时。
- `dateKey`：今日指引 JSON 中的日期 key，固定为 `yyyy-MM-dd`。

### 第二遍：理解 iPhone 界面

阅读 `iOS/DailyGuidance/DailyGuidance/ContentView.swift`：

- `ContentView` 是首页。
- `GuidanceSheet` 管理今日指引文件状态和编辑会话。
- `GuidanceTimelineView` 展示近 30 天时间流。
- `GuidanceEntryCard` 是单日卡片。
- `GuidanceStyledTextView` 把 UIKit 的 `UITextView` 接到 SwiftUI，保证编辑和展示换行一致。

SwiftUI 的重要习惯是：View 描述“状态长什么样”，Store 决定“状态如何变化”。不要在 View 中直接读写 JSON 或计算计时业务。

### 第三遍：理解锁屏与灵动岛

依次阅读：

1. `PomodoroLiveActivity/PomodoroLiveActivityBundle.swift`
2. `PomodoroLiveActivity/PomodoroLiveActivity.swift`
3. `PomodoroLiveActivity/PomodoroLiveActivityIntents.swift`

实时活动只负责显示 `PomodoroActivityAttributes.ContentState`。iOS 17 的按钮执行 App Intent，Intent 更新 App Group 中的 `PomodoroSharedSession`；主 App 收到通知或回到前台时再对账。

### 第四遍：理解 Mac 单文件应用

阅读 `Sources/main.swift` 中的 `MARK`：

1. 模型和兼容解码
2. 应用生命周期
3. 菜单构建
4. 计时状态机
5. 今日指引
6. 记录菜单与统计
7. iCloud 与本地回退
8. NSMenu actions

Mac 版没有 Xcode 工程，`scripts/build.sh` 直接使用 `swiftc` 编译 `main.swift`，再手工组装 `.app` 目录。

## iPhone 计时数据流

开始一段计时后，`PomodoroStore` 会同时做四件事：

```text
用户点击开始
  ├─ 更新 @Published 属性 → SwiftUI 首页刷新
  ├─ 保存 PersistedSession → App 重启后恢复
  ├─ 保存 PomodoroSharedSession → 锁屏按钮可以操作
  └─ 创建 Live Activity 与完成通知
```

前台的一秒 Timer 只负责刷新画面。真实时间来自：

```text
累计运行秒数 + 当前时间 - 最近一次继续时间
```

不要把逻辑改成“每次 Timer 触发就加一或减一”。iOS 进入后台后 Timer 会暂停，这样修改会造成明显计时误差。

暂停时，会把当前运行片段折算进累计秒数，并清空最近继续时间。继续时只记录一个新的起点。

## Live Activity 数据流

主 App 创建实时活动时传入：

- `sessionID`：不会变化的属性；
- `ContentState`：模式、运行状态和时间锚点，可更新。

锁屏按钮执行过程：

```text
Live Activity 按钮
  → App Intent 核对 sessionID
  → 修改 App Group 共享会话
  → 更新或结束 ActivityKit 活动
  → 重排或取消完成通知
  → 主 App 对账并刷新首页/记录
```

主 App 和扩展目录各有一份 `PomodoroActivityAttributes`，因为两个 target 分别编译。修改字段时必须同步两份，否则运行时的数据协议会不一致。

## 今日指引数据流

今日指引文件格式：

```json
{
  "2026-09-17" : "第一天的多行文字",
  "2026-09-18" : "今天的指引"
}
```

iPhone 首次访问时需要用户通过系统文件选择器选择 `daily-guidance.json`。系统返回的 URL 只能临时访问，因此 `GuidanceStore` 把 security-scoped bookmark 保存到 UserDefaults，下次启动再恢复授权。

保存某一天时，流程是：

1. 重新读取整个 JSON，吸收其他设备刚同步的内容。
2. 只替换目标日期。
3. 使用可读、按日期排序的 JSON 编码。
4. 通过原子写入替换文件。
5. 重新生成今天状态和近 30 天时间流。

编辑和展示都使用 `GuidanceStyledTextView`，所以字号、颜色、行距、内容宽度和自动换行相同。JSON 始终只保存纯文本，不保存字体或颜色。

## Mac 数据位置与兼容策略

Mac 默认目录：

```text
~/Library/Mobile Documents/com~apple~CloudDocs/PomodoroBar/
```

回退目录：

```text
~/.pomodoro-status-bar/
```

读取时会同时检查本地和 iCloud，并合并记录。iCloud 文件不可读时，本次运行不会覆盖它，而是回退到本地写入。

`PomodoroRecord` 的自定义解码器兼容早期字段。修改记录结构时应继续遵守：

- 新字段尽量提供默认值；
- 不删除用户无法重新生成的数据；
- 迁移成功保存前不删除旧数据；
- JSON 保持人类可读。

## 常见修改应该去哪里

| 需求 | 主要文件 |
| --- | --- |
| 修改 iPhone 首页布局或颜色 | `ContentView.swift` |
| 修改计时开始、暂停、完成规则 | `PomodoroStore.swift` |
| 修改今日指引读写或 30 天过滤 | `GuidanceStore.swift` |
| 修改锁屏/灵动岛布局 | `PomodoroLiveActivity.swift` |
| 修改锁屏按钮行为 | `PomodoroLiveActivityIntents.swift`、`PomodoroSharedSession.swift` |
| 修改 Mac 菜单、计时或数据 | `Sources/main.swift` |
| 修改 Mac 打包过程 | `scripts/build.sh` |

## 手动修改时的安全原则

1. **先区分显示状态和业务状态。** 颜色、边距放在 View；计时和文件规则放在 Store。
2. **时间用 Date 差值计算。** 不要依赖 Timer 调用次数。
3. **共享字段两边同步。** Activity attributes 和 App Group 模型改变后，要检查主 App 与扩展的所有构造位置。
4. **保留旧 JSON。** 新字段用可选值或默认值兼容，写入使用原子操作。
5. **异步结束前抓最终状态。** 重置内存后再读取会得到错误的锁屏最后一帧。
6. **不要把 iCloud URL 当普通文件 URL。** iPhone 上必须在 security-scoped 访问区间内读写。
7. **不要把敏感或大对象放入 UserDefaults。** 当前只保存小型 Codable 会话快照。

## 修改后的验证

Mac 源码或打包变化后：

```bash
./scripts/build.sh
```

Shell 脚本语法：

```bash
bash -n scripts/build.sh scripts/restart.sh
```

iPhone 代码需要在 Xcode 中选择 `PomodoroBar` scheme 和真机运行。重点手动检查：

- 开始、暂停、继续和结束；
- App 进后台再回来，时间是否正确；
- 锁屏和灵动岛按钮是否同步首页；
- 完成通知是否只出现一次；
- 今日指引多行编辑、历史日期编辑和 iCloud 重新加载；
- 编辑前后每行换行位置是否一致。

提交前还应确认 `git status --short --branch`，避免把 `dist/`、`.build/` 或无关草稿加入提交。
