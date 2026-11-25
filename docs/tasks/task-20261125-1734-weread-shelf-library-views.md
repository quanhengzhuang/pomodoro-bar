# WeReadShelf 图标、书架视图与阅读数据

## 目标

将独立 Mac 项目更名为 WeReadShelf，补齐应用图标，让用户浏览两份书单、查看单本阅读数据和从封面继续阅读。

## 改动

- 将目录、Xcode 工程、scheme、产物和应用显示名统一为 WeReadShelf，制作原创书架图标并接入 macOS 应用资源。
- 应用内的「最近阅读」和「自定义书单」各支持列表和格子，记住各自的布局选择。两种布局都支持自定义书单的增删和排序。
- 点击封面优先打开微信读书阅读器，缺少阅读器链接时打开官方书籍详情。移除原跳转箭头。[微信读书链接规范](https://github.com/Tencent/WeChatReading/blob/main/skills/SKILL.md)
- 两种布局都可显示单本累计阅读时长、进度百分比和最近阅读日期，已读完的书可查看读完日期。同步后自动获取最近 5 本电子书的阅读数据，其余书籍可按需查看，已获取的数据可离线查看。[阅读进度接口](https://github.com/Tencent/WeChatReading/blob/main/skills/book.md) · [官方阅读概况](https://github.com/Tencent/WeChatReading/blob/main/skills/profile.md)
- 「从书架选书」按最近阅读时间从新到旧排序，未读书排在末尾。搜索结果沿用同一顺序。

## 影响文件

- `macOS/WeRead/` → `macOS/WeReadShelf/`（工程、App、图标资源和阅读数据缓存）
- `README.md`、`docs/en/README.md`（新路径与使用说明）
- 本任务的中英文文档

## 预估代码行数

约 280–420 行 Swift 改动，另有项目配置和图标资源。

## 数据与验证重点

- 沿用 Bundle ID、App Group、Keychain 项、本地存储路径和两个小组件的标识。新版本继续读取旧书单，阅读数据按当前账号缓存。
- 验证累计时长单位、数据缺失、旧缓存、列表切换、选书排序和封面跳转，检查打包后的图标。构建独立工程并运行仓库 `./scripts/build.sh`。
