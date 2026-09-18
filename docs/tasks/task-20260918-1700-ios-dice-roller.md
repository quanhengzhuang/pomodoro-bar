# iOS 3D 骰子应用

## 目标

新增一个独立的 iOS 摇骰子应用，支持同时投掷 1–10 个骰子，并保留逐次投掷历史。

## 改动

- 新建独立的 SwiftUI iOS App 与 Xcode 工程，不改动现有番茄钟 App。
- 提供 1–10 个骰子的数量选择、总点数展示和每次一行的历史记录。
- 使用 SceneKit 物理碰撞、真实骰面、阴影、触觉反馈和收敛检测实现 3D 投掷动画。
- 采用胡桃木骰盘与象牙白骰子的视觉方向，并支持减少动态效果和 VoiceOver。

## 影响文件

- `iOS/DiceRoller/DiceRoller.xcodeproj/project.pbxproj`
- `iOS/DiceRoller/DiceRoller/DiceRollerApp.swift`
- `iOS/DiceRoller/DiceRoller/ContentView.swift`
- `iOS/DiceRoller/DiceRoller/DiceSceneView.swift`
- `iOS/DiceRoller/DiceRoller/Assets.xcassets/`

## 预估代码行数

约 650 行。
