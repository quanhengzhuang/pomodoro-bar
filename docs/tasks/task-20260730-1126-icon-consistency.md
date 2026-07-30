目标
- 以现有状态栏番茄 icon 为准，统一应用 icon 和 README 展示 icon，并检查打包使用的 icon 路径。

改动
- 检查 `Resources/AppIcon.icns`、`docs/assets/icon.png`、状态栏绘制逻辑和打包脚本的 icon 引用。
- 按现有状态栏番茄的颜色、形状和高光生成应用 icon 与 README 展示 icon。
- 启动时显式加载应用 icon，并让所有设置/确认弹窗使用同一个 icon，避免系统缓存旧图标。
- 构建后确认 app 仍使用 `AppIcon.icns`。

影响文件
- `Sources/main.swift`
- `Resources/AppIcon.icns`
- `docs/assets/icon.png`
- `Packaging/Info.plist`
- `scripts/build.sh`
- `docs/tasks/task-20260730-1126-icon-consistency.md`

预估代码行数
- 约 12 行代码，更新 1 个图片资源

实际变更
- 状态栏绘制和 `docs/assets/icon.png` 已一致，均保持不变。
- 使用 `docs/assets/icon.png` 的现有视觉生成并替换 `Resources/AppIcon.icns`。
- 启动时显式设置应用图标，并统一为备注、清空记录、清空完成、专注时长和无效时长弹窗指定该图标。
- `Packaging/Info.plist` 与 `scripts/build.sh` 的应用图标引用正确，保持不变。

验证结果
- `./scripts/build.sh` 构建成功；仅有现存的通知 API 弃用警告。
- 应用包内 `AppIcon.icns` 与 `Resources/AppIcon.icns` 完全一致。
- 所有 5 个 `NSAlert` 入口均通过统一构造方法加载应用包内的新图标。
