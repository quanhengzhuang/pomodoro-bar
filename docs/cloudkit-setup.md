# CloudKit 配置与恢复

## 数据范围

CloudKit Private Database 同步两类数据：已完成的番茄记录、按日期保存的今日指引。正在运行的计时、Live Activity 状态和设备偏好留在本机，避免设备之间互相接管计时。

容器固定为 `iCloud.local.codex.PomodoroBar`。数据属于当前登录的 iCloud 账户，不对其他用户公开。

## 首次配置

1. 在 Apple Developer 后台为团队创建或确认 CloudKit Container：`iCloud.local.codex.PomodoroBar`。
2. 将 iOS App ID `local.codex.PomodoroBar` 和 macOS App ID `local.codex.PomodoroBar` 关联到该容器。
3. 在 Xcode 打开 `iOS/DailyGuidance/DailyGuidance.xcodeproj`，选择 `PomodoroBar` target，在 Signing & Capabilities 选择同一团队，并确认 iCloud / CloudKit 下显示上述容器。
4. 重新生成包含 iCloud 权限的描述文件。旧描述文件不含新权限时，真机会拒绝安装或 CloudKit 会拒绝访问。
5. 先运行开发版并各保存一条番茄记录和一条今日指引，使 Development 环境创建 Schema。

当前团队必须支持 iCloud Capability；如果 Xcode 无法创建容器或描述文件，请先检查 Apple Developer 会员与 App ID 权限。

## Schema

开发环境首次写入后会出现以下 Record Type：

| Record Type | Record Name | 字段 |
| --- | --- | --- |
| `PomodoroSession` | JSON 的稳定 `id` | `startedAt` String、`endedAt` String、`date` String、`type` String、`durationSeconds` Int64、`note` String、`schemaVersion` Int64 |
| `DailyGuidance` | `yyyy-MM-dd` 日期 | `dateKey` String、`text` String、`modifiedAt` Timestamp、`schemaVersion` Int64 |

在 CloudKit Console 的 Development 环境核对类型和字段后，使用 Deploy Schema Changes 将 Schema 部署到 Production。生产版发布前必须完成这一步；客户端不能在 Production 环境动态创建 Record Type。

所有记录位于 Private Database。番茄记录按稳定 ID 去重且不删除；同一天的今日指引以 `modifiedAt` 较新的内容为准。CloudKit Console 可以查看或修改开发数据，但手工修改 `DailyGuidance` 时也要同步更新 `modifiedAt`，否则设备上的较新副本会覆盖它。

## Mac 开发签名

直接执行 `./scripts/build.sh` 会生成可离线运行的临时签名版本，但临时签名不能访问 CloudKit。测试 Mac 同步时，需要 Apple Development 证书和与 App ID、CloudKit Container 匹配的 macOS 描述文件：

```bash
POMODORO_CODESIGN_IDENTITY="Apple Development: 你的名字 (团队 ID)" \
POMODORO_PROVISIONING_PROFILE="/描述文件的绝对路径.provisionprofile" \
./scripts/build.sh
```

## 原文件与备份

迁移不会删除原 JSON。Mac 仍维护 iCloud Drive 或本机回退目录中的 `records.json`、`daily-guidance.json`，并在首次上传前复制到：

```text
~/.pomodoro-status-bar/Legacy Backups/<时间>/
```

iOS 的本地副本和迁移备份位于 App 容器：

```text
Library/Application Support/PomodoroBar/
Library/Application Support/PomodoroBar/Legacy Backups/
```

可在 Xcode 的 Devices and Simulators 中下载 App Container 后查看这些文件。配置入口选择的旧 `daily-guidance.json` 也会先备份，再导入 CloudKit，并继续作为人工可读镜像。

## 恢复

1. 先退出 Mac 与 iOS App，复制整个 `Legacy Backups` 目录到安全位置。
2. 从时间正确的备份取出 `records.json` 或 `daily-guidance.json`，恢复到 Mac 当前数据目录；不要删除其余备份。
3. 重新打开 Mac App。它会给没有 `id` 的旧记录生成稳定 ID，并将本机与 CloudKit 数据合并。
4. iOS 的旧今日指引也可通过配置入口选择 JSON 重新导入。

应用不会向 CloudKit 发出删除请求，因此恢复是追加/合并操作。若要进行不可逆的云端清理，应先导出备份，并在 CloudKit Console 明确核对 Development 或 Production 环境。
