# 全量源码学习注释

## 目标

为 Mac、iOS、实时活动和构建脚本补充面向初学者的详尽中文注释，方便理解并手动维护。

## 改动

- 为所有 Swift 源文件补充文件职责、类型用途、属性状态、主要方法、数据流和关键平台 API 注释。
- 使用 `MARK` 按功能整理长文件，重点解释计时状态转换、数据持久化、iCloud 文件授权、SwiftUI/UIKit/AppKit 衔接、Live Activity 与 App Intent 通信。
- 为构建和重启脚本逐段说明输入、输出、安全措施和执行流程。
- 新增中英文源码阅读指南，说明工程结构、建议阅读顺序、常见修改入口和验证方法。
- 注释解释“为什么”和维护注意点，不对每个显然的语法行重复释义，不改变现有行为。

## 影响文件

- `Sources/main.swift`
- `iOS/DailyGuidance/**/*.swift`
- `scripts/build.sh`
- `scripts/restart.sh`
- `docs/code-reading-guide.md`
- `docs/en/code-reading-guide.md`
- `README.md`
- `docs/en/README.md`
- `docs/tasks/task-20260918-1125-source-learning-comments.md`
- `docs/en/tasks/task-20260918-1125-source-learning-comments.md`

## 预估代码行数

约新增 1,000–1,600 行注释和学习文档，不增加业务逻辑。

## 验证重点

- 注释与当前实现一致，不掩盖或改变其他正在进行的修改。
- Swift 类型检查、Mac 构建、Shell 语法检查及差异检查通过。

## 实际变更

- 为 Mac App、iPhone 主 App、Live Activity、App Intent、共享会话模型及两个脚本补充中文文件说明、类型/方法文档、状态流转和维护注意点。
- 使用 `MARK` 整理长文件，重点说明真实时间计算、前后台恢复、记录兼容、iCloud 回退、安全范围书签、App Group 和锁屏按钮同步。
- 新增中英文源码阅读指南，包含工程结构、建议阅读顺序、主要数据流、常见修改入口、安全原则和验证清单。
- README 已增加源码阅读入口；业务逻辑和数据格式未改变。

## 验证结果

- iOS 主 App 和 Live Activity 扩展分别通过 iPhoneOS SDK 类型检查。
- `./scripts/build.sh` 构建成功，仅有已知的旧版 Mac 通知 API 弃用警告。
- `bash -n scripts/build.sh scripts/restart.sh` 和 `git diff --check` 通过。
- 已核对所有源码改动均为新增注释，未删除或替换现有业务代码。
