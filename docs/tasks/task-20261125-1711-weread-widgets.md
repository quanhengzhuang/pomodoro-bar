# 微信读书桌面小组件

## 目标

在 `macOS/WeRead/` 新建独立的 macOS 14+ 应用，查看微信读书最近阅读和一份自定义书单，并将两份列表分别添加到 Mac 桌面。

## 改动

- 在设置中提供微信读书官方 Key 申请入口，支持输入和更换 API Key，并存入 macOS 钥匙串。
- 通过官方 Skill 的 `/shelf/sync` 读取书架里的电子书，按最近阅读时间倒序展示。打开应用时自动同步，也支持手动刷新。[官方书架接口](https://github.com/Tencent/WeChatReading/blob/main/skills/shelf.md)
- 从完整电子书书架选择书籍，组成一份可增删和排序的本地自定义书单。
- 在 Mac 的“编辑小组件”中提供“最近阅读”和“自定义书单”两个 WidgetKit 小组件，可同时添加。小组件显示最近同步或编辑后保存的内容，点击打开应用中的对应列表。[Apple 的小组件添加指南](https://support.apple.com/guide/mac-help/add-and-customize-widgets-mchl52be5da5/mac)

## 影响文件

- `macOS/WeRead/`（独立 Xcode 工程、应用、小组件扩展和共享数据模型）
- `README.md`、`docs/en/README.md`（构建、配置签名和使用说明）
- 本任务的中英文文档

## 预估代码行数

约 500–700 行 Swift，另有 Xcode 工程配置。

## 验证重点

- 检查 Key 校验、近期排序、自定义书单持久化，以及离线时显示上次同步内容。
- 构建新 Xcode 工程并运行仓库 `./scripts/build.sh`。使用配置了 App Group 的签名构建，在桌面上添加两款小组件并验证列表更新。
