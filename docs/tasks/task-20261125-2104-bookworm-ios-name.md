# iOS 项目更名为 bookworm（书虫）

## 目标

将 iPhone 项目更名为 `bookworm`。英文界面使用 `bookworm`，简体中文界面使用「书虫」。

## 改动

- 将 iOS 项目目录、Xcode 工程、共享 scheme 及应用产物统一改为 `bookworm`，小组件扩展改为 `bookwormWidgets`。
- 本地化主屏幕和小组件库的应用显示名。继续提供「最近阅读」和「我的书单」两个小组件。
- 更新两份 README 中的 iPhone 工程路径、运行步骤和小组件搜索名称。

## 影响文件

- `iOS/WeReadShelf/` → `iOS/bookworm/`，涉及工程配置、共享 scheme、两个 `Info.plist` 及新增的 `InfoPlist.strings`。
- `README.md`、`docs/en/README.md` 的 iPhone 应用章节。

## 预估代码行数

约 50–100 行工程配置和本地化资源修改。

## 数据与验证重点

保留应用与扩展的 Bundle ID、App Group、两个小组件的标识、深链和存储键，兼容已有 API Key、书单和小组件。编译 iOS 模拟器版本，检查两个产物的显示名与标识，并运行 `./scripts/build.sh`。
