import ActivityKit
import SwiftUI
import WidgetKit

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 0.12, green: 0.02, blue: 0.03))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
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
                    HStack {
                        Label(context.state.isRunning ? "正在进行" : "已暂停", systemImage: context.state.isRunning ? "waveform.path.ecg" : "pause.fill")
                        Spacer()
                        Text("打开 Pomodoro Bar 管理")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                TomatoMark(size: 19)
            } compactTrailing: {
                TimerText(state: context.state, size: 15)
                    .frame(maxWidth: 54)
                    .minimumScaleFactor(0.7)
            } minimal: {
                TomatoMark(size: 18)
            }
            .keylineTint(Color.tomato)
        }
    }
}

private struct LockScreenView: View {
    let state: PomodoroActivityAttributes.ContentState

    var body: some View {
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
        .foregroundStyle(.white)
        .padding(16)
    }
}

private struct TimerText: View {
    let state: PomodoroActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        Group {
            if state.isRunning, state.isCountUp {
                Text(timerInterval: state.timerStart...Date.distantFuture, countsDown: false)
            } else if state.isRunning, let timerEnd = state.timerEnd {
                let now = Date()
                Text(timerInterval: now...max(now, timerEnd), countsDown: true)
            } else {
                Text(formattedTime(state.pausedSeconds))
            }
        }
        .font(.system(size: size, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
    }

    private func formattedTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }
}

private struct TomatoMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.tomato)
            Image(systemName: "leaf.fill")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(Color.leaf)
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

private extension Color {
    static let tomato = Color(red: 0.89, green: 0.18, blue: 0.17)
    static let tomatoLight = Color(red: 1.0, green: 0.45, blue: 0.30)
    static let leaf = Color(red: 0.31, green: 0.78, blue: 0.42)
}
