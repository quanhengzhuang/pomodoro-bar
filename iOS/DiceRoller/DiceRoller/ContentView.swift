import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var diceCount = 2
    @State private var rollToken = 0
    @State private var isRolling = false
    @State private var latestValues: [Int?] = []
    @State private var history: [RollRecord]

    init() {
        _history = State(initialValue: RollRecord.loadHistory())
    }

    var body: some View {
        ZStack {
            AppPalette.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    diceCountControl
                    tray
                    rollButton
                    historySection
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .onChange(of: diceCount) { _ in
            latestValues = []
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("骰盘")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(AppPalette.ivory)
                Text("PHYSICS DICE")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2.3)
                    .foregroundStyle(AppPalette.brass)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text(latestTotalText)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppPalette.ivory)
                    .minimumScaleFactor(0.7)
                Text(isRolling ? "逐个落下" : "总点数")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppPalette.mutedText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(totalAccessibilityLabel)
        }
    }

    private var diceCountControl: some View {
        HStack(spacing: 16) {
            Text("骰子数量")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ivory)

            Spacer()

            Button {
                diceCount = max(1, diceCount - 1)
                selectionFeedback()
            } label: {
                Image(systemName: "minus")
                    .frame(width: 40, height: 38)
            }
            .buttonStyle(CountButtonStyle())
            .disabled(diceCount == 1 || isRolling)
            .accessibilityLabel("减少骰子")

            Text("\(diceCount)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppPalette.ivory)
                .frame(minWidth: 24)
                .contentShape(Rectangle())
                .accessibilityLabel("\(diceCount) 枚骰子")

            Button {
                diceCount = min(10, diceCount + 1)
                selectionFeedback()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 40, height: 38)
            }
            .buttonStyle(CountButtonStyle())
            .disabled(diceCount == 10 || isRolling)
            .accessibilityLabel("增加骰子")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(AppPalette.panel)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppPalette.brass.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private var tray: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppPalette.walnutLight, AppPalette.walnut, AppPalette.walnutDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(AppPalette.brass.opacity(0.22), lineWidth: 1)
                .padding(8)

            DiceSceneView(
                diceCount: diceCount,
                rollToken: rollToken,
                reduceMotion: reduceMotion,
                accessibilityValue: trayAccessibilityValue
            ) { index, value in
                revealDie(at: index, value: value)
            } onRollFinished: { values in
                finishRoll(with: values)
            }
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            .padding(8)
        }
        // A landscape tray keeps the full play surface visible instead of making the table
        // read as a clipped square window on iPhone and Mac-designed-for-iPhone layouts.
        .frame(maxWidth: .infinity)
        .aspectRatio(1.45, contentMode: .fit)
        .shadow(color: .black.opacity(0.46), radius: 22, x: 0, y: 14)
        .accessibilityElement(children: .contain)
    }

    private var rollButton: some View {
        Button {
            guard !isRolling else { return }
            isRolling = true
            latestValues = Array(repeating: nil, count: diceCount)
            rollToken += 1
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.9)
        } label: {
            HStack(spacing: 10) {
                if isRolling {
                    ProgressView()
                        .tint(AppPalette.ink)
                } else {
                    Image(systemName: "die.face.5.fill")
                }
                Text(isRolling ? "骰子逐个落下" : "摇骰子")
                    .font(.headline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
        }
        .buttonStyle(RollButtonStyle())
        .disabled(isRolling)
        .accessibilityHint("投掷当前选择数量的骰子")
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("投掷历史")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppPalette.ivory)
                Spacer()
                Text("\(history.count) 次")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppPalette.mutedText)
            }

            if history.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundStyle(AppPalette.brass)
                    Text("第一次投掷后，结果会出现在这里。")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.mutedText)
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(AppPalette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(history) { record in
                        HistoryRow(record: record)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private var latestTotalText: String {
        let revealed = latestValues.compactMap { $0 }
        guard !revealed.isEmpty else { return "—" }
        return String(revealed.reduce(0, +))
    }

    private var totalAccessibilityLabel: String {
        if isRolling {
            return "已落定 \(latestValues.compactMap { $0 }.count) 枚，共 \(diceCount) 枚"
        }
        let revealed = latestValues.compactMap { $0 }
        guard !revealed.isEmpty else { return "尚未投掷" }
        return "总点数 \(revealed.reduce(0, +))"
    }

    private var trayAccessibilityValue: String {
        if isRolling {
            let values = latestValues.compactMap { $0 }.map(String.init).joined(separator: "、")
            return values.isEmpty ? "\(diceCount) 枚骰子正在逐个落下" : "已落定骰面：\(values)"
        }
        let revealed = latestValues.compactMap { $0 }
        guard !revealed.isEmpty else { return "\(diceCount) 枚骰子，等待投掷" }
        return "骰面为 \(revealed.map(String.init).joined(separator: "、"))"
    }

    private func revealDie(at index: Int, value: Int) {
        guard latestValues.indices.contains(index) else { return }
        latestValues[index] = value
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
    }

    private func finishRoll(with values: [Int]) {
        guard isRolling, values.count == diceCount else { return }
        latestValues = values.map(Optional.some)
        isRolling = false

        let record = RollRecord(values: values)
        history.insert(record, at: 0)
        history = Array(history.prefix(100))
        RollRecord.saveHistory(history)

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func selectionFeedback() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

private struct HistoryRow: View {
    let record: RollRecord

    var body: some View {
        HStack(spacing: 12) {
            Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption.monospacedDigit())
                .foregroundStyle(AppPalette.mutedText)
                .frame(width: 52, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(record.values.enumerated()), id: \.offset) { _, value in
                        Image(systemName: "die.face.\(value).fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppPalette.ivory)
                    }
                }
            }

            Spacer(minLength: 4)

            Text("= \(record.total)")
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .foregroundStyle(AppPalette.brass)
                .fixedSize()
        }
        .frame(height: 48)
        .padding(.horizontal, 14)
        .background(AppPalette.panel, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(record.accessibilityLabel)
    }
}

private struct RollRecord: Identifiable, Codable {
    static let historyKey = "diceRoller.history.v1"

    let id: UUID
    let timestamp: Date
    let values: [Int]

    init(id: UUID = UUID(), timestamp: Date = Date(), values: [Int]) {
        self.id = id
        self.timestamp = timestamp
        self.values = values
    }

    var total: Int { values.reduce(0, +) }

    var accessibilityLabel: String {
        "\(timestamp.formatted(date: .omitted, time: .shortened))，骰面 \(values.map(String.init).joined(separator: "、"))，总点数 \(total)"
    }

    static func loadHistory() -> [RollRecord] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let records = try? JSONDecoder().decode([RollRecord].self, from: data) else {
            return []
        }
        return records
    }

    static func saveHistory(_ records: [RollRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }
}

private struct CountButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AppPalette.ivory)
            .background(Circle().fill(AppPalette.ivory.opacity(configuration.isPressed ? 0.18 : 0.09)))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(isEnabled ? 1 : 0.3)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct RollButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppPalette.ink)
            .background(
                LinearGradient(
                    colors: [AppPalette.brassLight, AppPalette.brass],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 19, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: AppPalette.brass.opacity(isEnabled ? 0.22 : 0), radius: 16, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.7)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private enum AppPalette {
    static let background = Color(red: 0.075, green: 0.057, blue: 0.047)
    static let panel = Color(red: 0.125, green: 0.102, blue: 0.086)
    static let walnutDark = Color(red: 0.105, green: 0.055, blue: 0.031)
    static let walnut = Color(red: 0.255, green: 0.128, blue: 0.074)
    static let walnutLight = Color(red: 0.38, green: 0.205, blue: 0.115)
    static let brass = Color(red: 0.84, green: 0.61, blue: 0.28)
    static let brassLight = Color(red: 0.95, green: 0.76, blue: 0.42)
    static let ivory = Color(red: 0.97, green: 0.94, blue: 0.86)
    static let mutedText = Color(red: 0.67, green: 0.63, blue: 0.56)
    static let ink = Color(red: 0.10, green: 0.075, blue: 0.055)
}
