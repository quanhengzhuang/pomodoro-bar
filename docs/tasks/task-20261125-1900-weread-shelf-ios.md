# WeReadShelf iPhone 应用与主屏幕小组件

## 目标

在 `iOS/WeReadShelf/` 新建原生 SwiftUI 工程，支持 iOS 17 及以上。在 iPhone 上查看微信读书的两份列表，并分别添加到主屏幕。

## 改动

- 沿用 WeReadShelf 名称和蓝底叠书图标。应用内配置微信读书 API Key，保存到 iOS 钥匙串。启动和下拉刷新时同步书架。
- 提供「最近阅读」和「我的书单」的列表与格子布局。支持查看最近阅读日期和可用累计时长，点击封面打开微信读书。从书架按最近阅读顺序选书，书单内支持排序和确认移出。
- 提供「最近阅读」和「我的书单」两个 WidgetKit 主屏幕小组件，各支持小号和中号。同步或编辑书单后更新本机快照，点小组件打开应用里的对应书单。[Apple 主屏幕小组件指南](https://support.apple.com/zh-cn/118610)
- iOS 和 macOS 共用微信读书接口、书单数据模型、存储及小组件逻辑。iPhone 的书单和缓存保存在本机。

## 影响文件

- `iOS/WeReadShelf/`（Xcode 工程、iPhone 界面、图标和签名配置）
- iOS 工程引用 `macOS/WeReadShelf/` 内现有的通用 Swift 源码
- `README.md`、`docs/en/README.md` 和本任务的中英文文档

## 预估代码行数

约 300–500 行新增或修改的 Swift 代码，另有 Xcode 工程和资源配置。

## 数据与验证重点

- iOS 应用与扩展使用同一 App Group 交换可显示的书单数据。API Key 保存在应用自己的钥匙串范围内。[Apple App Groups 文档](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- 验证 iOS 模拟器构建、列表编辑、组件快照和点击跳转，并构建 macOS 工程及运行仓库 `./scripts/build.sh`。iPhone 真机验证需配置同一个可使用 App Groups 的 Apple Developer Team。
