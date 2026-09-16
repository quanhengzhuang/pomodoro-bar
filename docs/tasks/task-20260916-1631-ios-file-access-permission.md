# 修复 iOS 文件访问授权

## 目标

修复真机选择 iCloud Drive 中的 `daily-guidance.json` 后提示“无法保存文件访问权限”的问题。

## 改动

- 创建和更新文件书签前，先开启系统授予的安全范围文件访问，完成后及时释放。
- 保持 App 只读，不改变 JSON 格式或 iCloud 数据。
- 保留用户已选择的 Xcode 开发团队配置，并补充更便于排查的失败提示。

## 影响文件

- `iOS/DailyGuidance/DailyGuidance/GuidanceStore.swift`
- `docs/tasks/task-20260916-1631-ios-file-access-permission.md`
- `docs/en/tasks/task-20260916-1631-ios-file-access-permission.md`

## 预估代码行数

约 15–25 行代码及任务记录。

## 验证重点

- 真机首次选择 iCloud 文件后可立即读取，并在 App 重启后继续访问。
- 不覆盖开发团队配置，不写入或修改所选 JSON 文件。

## 实际变更

- 新增统一的安全范围访问方法，创建书签、续期书签和读取文件时均先获取访问权，完成后及时释放。
- 保存书签失败时显示系统返回的具体原因，便于继续排查真机问题。
- 保持文件只读，并保留现有开发团队配置。

## 验证结果

- Swift 源码类型检查通过，Xcode 工程及 Scheme 校验通过。
- 通用 iPhone Debug 构建成功，资源编译、Swift 编译、链接和 App 校验均完成。
- `./scripts/build.sh` 构建成功，仅有既有通知 API deprecated 警告。
- 真机的首次选择和重启后访问仍需安装新版本后实际确认。
