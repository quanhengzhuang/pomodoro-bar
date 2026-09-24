// 锁屏实时活动与灵动岛的全部 SwiftUI 界面。
//
// 这是 Widget Extension 中的代码，不是主 App 页面。系统会在受限环境中渲染它，
// 因此这里不维护业务状态，只根据 ActivityKit 传入的 attributes/state 生成界面。
import ActivityKit
import SwiftUI
import WidgetKit

/// 注册番茄钟实时活动的锁屏、灵动岛展开/紧凑/最小布局。
struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        // `ActivityConfiguration` 的泛型必须与主 App 请求活动时使用的类型相同。
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            // 第一个闭包描述锁屏通知样式。
            LockScreenView(sessionID: context.attributes.sessionID, state: context.state)
                .activityBackgroundTint(Color(red: 0.12, green: 0.02, blue: 0.03))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            // 灵动岛有展开、紧凑和最小三种系统决定的显示形态。
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TomatoMark(size: 30)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.modeTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    TimerText(state: context.state, size: 34)
                        .padding(.top, 2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // 可交互 Live Activity 按钮从 iOS 17 开始支持。
                    if #available(iOS 17.0, *) {
                        LiveActivityControls(
                            sessionID: context.attributes.sessionID,
                            state: context.state
                        )
                    } else {
                        // iOS 16.1–16.x 只能展示状态，引导用户回主 App 操作。
                        HStack {
                            Label(
                                context.state.isRunning ? "正在进行" : "已暂停",
                                systemImage: context.state.isRunning ? "waveform.path.ecg" : "pause.fill"
                            )
                            Spacer()
                            Text("打开 Pomodoro Bar 管理")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    }
                }
            } compactLeading: {
                // App 在灵动岛紧凑形态的左半边。
                TomatoMark(size: 19)
            } compactTrailing: {
                // 右半边空间很窄，需要限制宽度并允许缩小文字。
                TimerText(state: context.state, size: 15)
                    .frame(maxWidth: 54)
                    .minimumScaleFactor(0.7)
            } minimal: {
                // 多个实时活动并存时，系统可能只显示最小圆形图标。
                TomatoMark(size: 18)
            }
            .keylineTint(Color.tomato)
        }
    }
}

/// 锁屏上完整显示的一张实时活动卡片。
private struct LockScreenView: View {
    /// 交互按钮把这个 UUID 传给 App Intent，以核对操作目标。
    let sessionID: UUID
    /// 由 ActivityKit 提供的当前动态状态。
    let state: PomodoroActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 13) {
            HStack(spacing: 14) {
                TomatoMark(size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.modeTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.tomatoLight)
                    TimerText(state: state, size: 31)
                }

                Spacer(minLength: 10)

                Image(systemName: state.isRunning ? "waveform.path.ecg" : "pause.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(state.isRunning ? Color.leaf : Color.orange)
                    .accessibilityLabel(state.isRunning ? "正在进行" : "已暂停")
            }

            if #available(iOS 17.0, *) {
                // 锁屏和展开灵动岛复用同一组按钮，保证行为一致。
                LiveActivityControls(sessionID: sessionID, state: state)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}

/// iOS 17+ 的暂停/继续、延长和结束按钮。
///
/// `Button(intent:)` 不会先打开主 App，而是让系统直接执行对应 `LiveActivityIntent`。
@available(iOS 17.0, *)
private struct LiveActivityControls: View {
    let sessionID: UUID
    let state: PomodoroActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            // 文案和图标根据最新 Activity 状态在“暂停/继续”之间切换。
            Button(intent: TogglePomodoroIntent(sessionID: sessionID)) {
                Label(
                    state.isRunning ? "暂停" : "继续",
                    systemImage: state.isRunning ? "pause.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(LiveActivityActionButtonStyle())

            // 自由计时没有计划终点，因此“加 5 分”没有意义。
            if !state.isCountUp {
                Button(intent: AddFiveMinutesIntent(sessionID: sessionID)) {
                    Label("加 5 分", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LiveActivityActionButtonStyle())
            }

            // 结束是不可逆的主操作，使用红色破坏性样式强调。
            Button(intent: EndPomodoroIntent(sessionID: sessionID)) {
                Label("结束", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LiveActivityActionButtonStyle(isDestructive: true))
        }
        .font(.caption.weight(.semibold))
        .labelStyle(.titleAndIcon)
    }
}

/// Live Activity 专用的半透明胶囊按钮样式。
@available(iOS 17.0, *)
private struct LiveActivityActionButtonStyle: ButtonStyle {
    /// `true` 时在系统材质上叠加半透明番茄红，当前仅用于“结束”。
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .padding(.vertical, 9)
            .padding(.horizontal, 8)
            .foregroundStyle(.white)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    // 实时活动本身始终使用深色背景；深色材质保持白字对比度。
                    .environment(\.colorScheme, .dark)
                    .overlay {
                        Capsule().fill(
                            isDestructive
                                ? Color.tomato.opacity(configuration.isPressed ? 0.42 : 0.62)
                                : Color.white.opacity(configuration.isPressed ? 0.14 : 0.04)
                        )
                    }
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(isDestructive ? 0.24 : 0.16), lineWidth: 1)
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// 让系统根据时间区间自行刷新的计时文本。
///
/// 运行时使用 `Text(timerInterval:)`，无需扩展每秒执行代码；暂停时使用固定字符串，
/// 避免系统继续推进已经冻结的计时。
private struct TimerText: View {
    let state: PomodoroActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        Group {
            if state.isRunning, state.isCountUp {
                // 从真实起点正向计时；使用 distantFuture 构造一个足够长的区间。
                Text(timerInterval: state.timerStart...Date.distantFuture, countsDown: false)
            } else if state.isRunning, let timerEnd = state.timerEnd {
                let now = Date()
                // max 防止结束时间已过去时构造反向区间。
                Text(timerInterval: now...max(now, timerEnd), countsDown: true)
            } else {
                Text(formattedTime(state.pausedSeconds))
            }
        }
        .font(.system(size: size, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
    }

    /// 格式化暂停后的固定秒数，且不允许负数出现在界面。
    private func formattedTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }
}

/// 用纯 SwiftUI 图形绘制的小番茄，避免 Widget 扩展依赖位图资源。
struct TomatoMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // 红色圆形是果实；叶子也用几何路径绘制，避免锁屏快捷控制只提取出一个 SF Symbol。
            Circle().fill(Color.tomato)
            TomatoLeaf()
                .foregroundStyle(Color.leaf)
                .frame(width: size * 0.44, height: size * 0.27)
                .offset(x: size * 0.12, y: -size * 0.29)
            Circle()
                .trim(from: 0.04, to: 0.83)
                .stroke(Color.tomatoLight, style: StrokeStyle(lineWidth: max(1.5, size * 0.08), lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(size * 0.16)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 番茄顶部的叶子。使用闭合几何路径，确保实时活动和锁屏控制渲染出完整图标。
private struct TomatoLeaf: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let left = rect.minX
        let right = rect.maxX
        let top = rect.minY
        let bottom = rect.maxY
        let middle = rect.midX

        path.move(to: CGPoint(x: middle, y: bottom))
        path.addCurve(
            to: CGPoint(x: left, y: top + rect.height * 0.34),
            control1: CGPoint(x: left + rect.width * 0.03, y: bottom - rect.height * 0.03),
            control2: CGPoint(x: left + rect.width * 0.01, y: top + rect.height * 0.03)
        )
        path.addCurve(
            to: CGPoint(x: middle, y: top + rect.height * 0.18),
            control1: CGPoint(x: left + rect.width * 0.40, y: top + rect.height * 0.11),
            control2: CGPoint(x: middle - rect.width * 0.10, y: top + rect.height * 0.16)
        )
        path.addCurve(
            to: CGPoint(x: right, y: top),
            control1: CGPoint(x: middle + rect.width * 0.12, y: top + rect.height * 0.05),
            control2: CGPoint(x: right - rect.width * 0.04, y: top + rect.height * 0.01)
        )
        path.addCurve(
            to: CGPoint(x: middle, y: bottom),
            control1: CGPoint(x: right - rect.width * 0.02, y: bottom - rect.height * 0.02),
            control2: CGPoint(x: middle + rect.width * 0.12, y: bottom - rect.height * 0.01)
        )
        path.closeSubpath()
        return path
    }
}

/// 扩展内使用的品牌色。Widget target 无法自动访问主 App 的私有 Color 扩展。
private extension Color {
    static let tomato = Color(red: 0.89, green: 0.18, blue: 0.17)
    static let tomatoLight = Color(red: 1.0, green: 0.45, blue: 0.30)
    static let leaf = Color(red: 0.31, green: 0.78, blue: 0.42)
}
