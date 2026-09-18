// iOS 主界面与“今日指引”界面。
//
// 本文件主要描述视图结构和短暂的交互状态；计时业务在 PomodoroStore，文件读写在
// GuidanceStore。保持这种分工后，修改颜色或布局不会意外改变计时和数据逻辑。
import SwiftUI
import UniformTypeIdentifiers

/// App 首页：模式选择、计时盘、控制按钮、今日统计和最近记录。
struct ContentView: View {
    /// 由 App 入口创建并注入；ObservedObject 表示本视图不拥有其生命周期。
    @ObservedObject var store: PomodoroStore
    @ObservedObject var guidanceStore: GuidanceStore

    /// 深浅色用于选择可读的品牌色。
    @Environment(\.colorScheme) private var colorScheme
    /// 用户开启“减少动态效果”时禁用进度环动画。
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 随系统动态字体缩放计时数字，同时保持相对 largeTitle 的视觉层级。
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize = 56
    // 以下 State 只属于当前页面交互，不需要写入业务 Store。
    @State private var isSelectingGuidance = false
    @State private var isShowingGuidance = false
    @State private var isEditingNote = false
    @State private var isAdjustingTime = false
    @State private var draftNote = ""
    @State private var adjustmentMinutes = "5"
    @State private var showInvalidAdjustment = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    modePicker
                    guidanceEntry
                    timerFace
                    controls
                    todaySummary
                    recentRecords
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 36)
            }
            .background(background)
            .navigationTitle("Pomodoro Bar")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(.tomato)
        .fileImporter(
            isPresented: $isSelectingGuidance,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            // 用户取消选择时 result 不是 success，保持原状态即可。
            guard case .success(let urls) = result, let url = urls.first else { return }
            guidanceStore.selectFile(url)
            isShowingGuidance = true
        }
        .sheet(isPresented: $isShowingGuidance) {
            GuidanceSheet(store: guidanceStore) {
                isShowingGuidance = false
                isSelectingGuidance = true
            }
        }
        .alert("本段备注", isPresented: $isEditingNote) {
            TextField("例如：写方案、读论文、修 bug", text: $draftNote)
            Button("取消", role: .cancel) {}
            Button("保存") { store.updateNote(draftNote) }
        } message: {
            Text("备注会随本段记录一起保存。")
        }
        .alert("调整时间", isPresented: $isAdjustingTime) {
            TextField("5 或 -5", text: $adjustmentMinutes)
                .keyboardType(.numbersAndPunctuation)
            Button("取消", role: .cancel) {}
            Button("调整") {
                // 同时限制输入范围，并把具体“调整后是否仍有剩余时间”的判断交给 Store。
                guard let minutes = Int(adjustmentMinutes), (-180...180).contains(minutes),
                      store.adjustCountdown(minutes: minutes) else {
                    showInvalidAdjustment = true
                    return
                }
            }
        } message: {
            Text("输入 -180 到 180 之间的非零整数分钟。")
        }
        .alert("调整时长无效", isPresented: $showInvalidAdjustment) {
            Button("好", role: .cancel) {}
        } message: {
            Text("请确保调整后仍有剩余时间。")
        }
        .alert("无法完成操作", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: - 首页组成部分

    /// 把重要的指引入口放在内容区，比顶栏小图标更容易发现和点击。
    private var guidanceEntry: some View {
        Button(action: openGuidance) {
            HStack(spacing: 14) {
                Image(systemName: "quote.opening")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.tomato)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.tomato.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text("今日指引")
                        .font(.subheadline.weight(.semibold))
                    Text(guidanceStore.hasSelectedFile ? "查看与编辑今天的方向" : "选择数据文件后开始使用")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.card))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("今日指引")
        .accessibilityHint(guidanceStore.hasSelectedFile ? "查看与编辑指引" : "选择指引数据文件")
    }

    /// 四种计时模式的横向选择器。
    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(store.modeOptions) { mode in
                Button {
                    store.selectMode(mode)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: mode.symbolName)
                            .font(.callout.weight(.semibold))
                        Text(mode.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(store.selectedMode == mode ? Color.white : Color.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(store.selectedMode == mode ? Color.tomato : Color.card)
                    )
                }
                .buttonStyle(.plain)
                // 活动会话中禁止换模式，否则当前计时字段的语义会突然改变。
                .disabled(store.hasActiveSession)
                .opacity(store.hasActiveSession && store.selectedMode != mode ? 0.45 : 1)
            }
        }
    }

    /// 已绑定文件时直接打开；首次使用时先让用户选择数据文件。
    private func openGuidance() {
        if guidanceStore.hasSelectedFile {
            // 每次打开前重新读文件，以看到 Mac/iCloud 的最新修改。
            guidanceStore.refresh()
            isShowingGuidance = true
        } else {
            isSelectingGuidance = true
        }
    }

    /// 番茄形环形进度、状态、时间、模式和备注。
    private var timerFace: some View {
        ZStack {
            Circle()
                .stroke(Color.tomato.opacity(0.12), lineWidth: 22)

            Circle()
                // 至少绘制极短弧线，使 0 进度时仍有明确的起点。
                .trim(from: 0, to: max(0.002, store.progress))
                .stroke(
                    AngularGradient(colors: [.tomatoDark, .tomato, .tomatoLight, .tomato], center: .center),
                    style: StrokeStyle(lineWidth: 22, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: store.progress)

            ForEach(0..<8, id: \.self) { index in
                // 八个刻度每隔 45 度放置一次。
                Capsule()
                    .fill(Color.tomato.opacity(0.20))
                    .frame(width: 3, height: 11)
                    .offset(y: -119)
                    .rotationEffect(.degrees(Double(index) * 45))
            }

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.isRunning ? Color.leaf : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(statusText)
                        .font(.caption.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                }

                Text(formattedTime(store.displaySeconds))
                    .font(.system(size: timerFontSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.65)

                Text(store.selectedMode.title)
                    .font(.headline)
                    .foregroundStyle(colorScheme == .dark ? Color.tomatoLight : Color.tomatoDark)

                if !store.note.isEmpty {
                    Text(store.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
            }
        }
        .frame(width: 278, height: 278)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        // VoiceOver 将整个计时盘读成一条有意义的句子，而不是逐个朗读装饰图形。
        .accessibilityLabel("\(store.selectedMode.title)，\(formattedTime(store.displaySeconds))，\(statusText)")
    }

    /// 备注、主操作、结束和调整时长按钮。
    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    draftNote = store.note
                    isEditingNote = true
                } label: {
                    Label("备注", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(QuietButtonStyle())

                Button {
                    store.performPrimaryAction()
                } label: {
                    Label(store.primaryActionTitle, systemImage: primaryActionSymbol)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SessionActionButtonStyle(isProminent: !store.hasActiveSession))

                Button {
                    store.endSession()
                } label: {
                    Label("结束", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SessionActionButtonStyle(isProminent: store.hasActiveSession))
                .disabled(!store.hasActiveSession)
            }

            if store.hasActiveSession && store.selectedMode != .countUp {
                Button {
                    adjustmentMinutes = "5"
                    isAdjustingTime = true
                } label: {
                    Label("调整本段时间", systemImage: "plusminus.circle")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    /// 当天专注时长、记录数量和 Live Activity 状态摘要。
    private var todaySummary: some View {
        HStack(spacing: 0) {
            summaryCell(value: formattedDuration(store.todayFocusSeconds), label: "今日专注")
            Divider().frame(height: 38)
            summaryCell(value: "\(store.todaySessionCount)", label: "完成时段")
            Divider().frame(height: 38)
            summaryCell(value: liveActivityStatus, label: "实时活动")
        }
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.card))
    }

    /// 最多显示 Store 提供的五条最近记录；无记录时完全隐藏区域。
    @ViewBuilder
    private var recentRecords: some View {
        if !store.recentRecords.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("最近记录")
                    .font(.headline)

                ForEach(store.recentRecords) { record in
                    HStack(spacing: 12) {
                        Image(systemName: record.mode.symbolName)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(record.mode == .focus ? Color.tomato : Color.leaf)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.card))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.note.isEmpty ? record.mode.title : record.note)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text("\(record.timeRange) · \(formattedDuration(record.durationSeconds))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 三列摘要中复用的单元格。
    private func summaryCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 很淡的品牌色渐变，在深浅色模式中都以系统背景为主。
    private var background: some View {
        LinearGradient(
            colors: [Color(uiColor: .systemBackground), Color.tomato.opacity(0.035)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - 首页显示文本

    private var statusText: String {
        guard store.hasActiveSession else { return "准备开始" }
        return store.isRunning ? "正在进行" : "已暂停"
    }

    private var primaryActionSymbol: String {
        guard store.hasActiveSession else { return "play.fill" }
        return store.isRunning ? "pause.fill" : "play.fill"
    }

    private var liveActivityStatus: String {
        guard store.liveActivityEnabled else { return "未启用" }
        return store.hasActiveSession ? "已开启" : "待开始"
    }

    private func formattedTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func formattedDuration(_ seconds: Int) -> String {
        if seconds >= 3600 {
            return String(format: "%d小时%02d分", seconds / 3600, (seconds % 3600) / 60)
        }
        return "\(seconds / 60)分钟"
    }
}

// MARK: - 今日指引 Sheet

/// 今日指引的模态页面，负责文件状态、编辑会话、保存/取消工具栏和错误提示。
private struct GuidanceSheet: View {
    @ObservedObject var store: GuidanceStore
    let selectAnotherFile: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    /// 当前编辑框内容。只有点击保存时才写入 GuidanceStore。
    @State private var draftGuidance = ""
    /// 非 nil 表示正在编辑该日期；同时也决定工具栏切换到保存/取消。
    @State private var editingDateKey: String?
    /// 用于判断草稿是否真的变化，从而禁用无意义的保存按钮。
    @State private var editingOriginalGuidance = ""

    var body: some View {
        NavigationStack {
            Group {
                switch store.state {
                case .noFile:
                    stateView(symbol: "icloud.and.arrow.down", title: "选择今日指引数据", message: "请选择 iCloud Drive/PomodoroBar/daily-guidance.json。")
                case .loading:
                    ProgressView("正在读取今日指引…")
                case .content, .empty:
                    // 今天为空并不代表历史为空，所以两种状态都展示时间流。
                    GuidanceTimelineView(
                        store: store,
                        draftGuidance: $draftGuidance,
                        editingDateKey: editingDateKey,
                        beginEditing: beginEditing
                    )
                case .error(let message):
                    stateView(symbol: "exclamationmark.icloud", title: "无法显示今日指引", message: message)
                }
            }
            .navigationTitle(isEditing ? "编辑指引" : "今日指引")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Button("取消", action: finishEditing)
                    } else {
                        Button("关闭") { dismiss() }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("保存") {
                            guard let editingDateKey else { return }
                            if store.saveGuidance(draftGuidance, forDateKey: editingDateKey) {
                                finishEditing()
                            }
                        }
                        .fontWeight(.semibold)
                        // 没有改动时不写文件，减少 iCloud 无意义同步。
                        .disabled(draftGuidance == editingOriginalGuidance)
                    } else {
                        if canEditGuidance {
                            Button {
                                beginEditing(store.todayDateKey, store.todayGuidance)
                            } label: {
                                Image(systemName: "square.and.pencil")
                            }
                            .accessibilityLabel("修改今日指引")
                        }
                        Button(action: selectAnotherFile) { Image(systemName: "doc.badge.gearshape") }
                        if store.hasSelectedFile {
                            Button(action: store.refresh) { Image(systemName: "arrow.clockwise") }
                        }
                    }
                }
            }
        }
        .onAppear {
            // Sheet 首次出现时让草稿与 Store 对齐。
            draftGuidance = store.todayGuidance
        }
        .onChange(of: store.todayGuidance) { guidance in
            // 编辑过程中不要用外部刷新覆盖用户尚未保存的输入。
            if !isEditing {
                draftGuidance = guidance
            }
        }
        .alert("无法保存指引", isPresented: Binding(
            get: { store.saveErrorMessage != nil },
            set: { if !$0 { store.clearSaveError() } }
        )) {
            Button("好", role: .cancel) { store.clearSaveError() }
        } message: {
            Text(store.saveErrorMessage ?? "")
        }
    }

    /// 文件未选择、读取失败等状态共用的说明页面。
    private func stateView(symbol: String, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 40, weight: .light)).foregroundStyle(guidanceColor)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("选择数据文件", action: selectAnotherFile).buttonStyle(.borderedProminent)
        }
        .padding(30)
    }

    /// 与正文相同的暖黄色，用于状态图标。
    private var guidanceColor: Color {
        colorScheme == .dark
            ? Color(red: 0.98, green: 0.73, blue: 0.22)
            : Color(red: 0.58, green: 0.39, blue: 0.05)
    }

    /// 只有文件已成功读取后才允许进入编辑，避免在错误状态下覆盖文件。
    private var canEditGuidance: Bool {
        switch store.state {
        case .content, .empty:
            return store.hasSelectedFile
        case .noFile, .loading, .error:
            return false
        }
    }

    /// 用一个可选日期表达编辑状态，比额外维护 Bool 更不易出现不同步。
    private var isEditing: Bool {
        editingDateKey != nil
    }

    /// 进入某一天的编辑模式，同时保存原文以支持变更检测。
    private func beginEditing(_ dateKey: String, _ guidance: String) {
        draftGuidance = guidance
        editingOriginalGuidance = guidance
        editingDateKey = dateKey
    }

    /// 退出编辑并恢复今天的最新内容；不会自行保存。
    private func finishEditing() {
        editingDateKey = nil
        editingOriginalGuidance = ""
        draftGuidance = store.todayGuidance
    }
}

/// 最近 30 天的纵向时间流。
///
/// 平时一次展示所有卡片；进入编辑后只保留目标卡片，避免键盘出现时用户误编辑错日期。
private struct GuidanceTimelineView: View {
    @ObservedObject var store: GuidanceStore
    @Binding var draftGuidance: String
    let editingDateKey: String?
    let beginEditing: (String, String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                if let editingDateKey {
                    if editingDateKey == store.todayDateKey {
                        editableCard(date: store.todayDate, isToday: true)
                    } else if let entry = pastEntries.first(where: { $0.dateKey == editingDateKey }) {
                        editableCard(date: entry.date, isToday: false)
                    }
                } else {
                    timeline
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
    }

    /// 今天固定单独置顶，所以从历史数组排除今天，避免重复卡片。
    private var pastEntries: [GuidanceHistoryEntry] {
        store.historyEntries.filter { $0.dateKey != store.todayDateKey }
    }

    /// 非编辑状态下的完整时间流内容。
    @ViewBuilder
    private var timeline: some View {
        GuidanceEntryCard(
            date: store.todayDate,
            guidance: $draftGuidance,
            isEditable: false,
            isToday: true,
            onEdit: { beginEditing(store.todayDateKey, store.todayGuidance) }
        )

        if pastEntries.isEmpty {
            Text("近 30 天暂无其他指引")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
        } else {
            ForEach(pastEntries) { entry in
                GuidanceEntryCard(
                    date: entry.date,
                    guidance: .constant(entry.guidance),
                    isEditable: false,
                    isToday: false,
                    onEdit: { beginEditing(entry.dateKey, entry.guidance) }
                )
            }
        }
    }

    /// 构造当前正在编辑的单张卡片。
    private func editableCard(date: Date, isToday: Bool) -> some View {
        GuidanceEntryCard(
            date: date,
            guidance: $draftGuidance,
            isEditable: true,
            isToday: isToday,
            onEdit: nil
        )
    }
}

/// 时间流中的日期卡片。
///
/// 展示和编辑共用相同的 `GuidanceStyledTextView`，因此颜色、字体、行距、内容宽度和
/// 自动换行位置完全一致，只通过 `isEditable` 切换输入能力。
private struct GuidanceEntryCard: View {
    let date: Date
    @Binding var guidance: String
    let isEditable: Bool
    let isToday: Bool
    let onEdit: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Self.dateFormatter.string(from: date))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isToday {
                    Text("今天")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(guidanceColor)
                } else if let onEdit {
                    // 历史日期可直接进入编辑；今天的编辑入口放在顶栏，减少重复按钮。
                    Button(action: onEdit) {
                        Image(systemName: "square.and.pencil")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(guidanceColor)
                    .accessibilityLabel("编辑\(Self.dateFormatter.string(from: date))的指引")
                }
            }

            ZStack(alignment: .topLeading) {
                // UIKit 桥接组件负责真正的文字布局；空文本时由上层叠加占位文案。
                GuidanceStyledTextView(
                    text: $guidance,
                    isEditable: isEditable,
                    textColor: UIColor(guidanceColor)
                )

                if guidance.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(isEditable ? guidanceColor.opacity(0.48) : Color.secondary)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.card))
    }

    /// 深色模式使用更亮的黄，浅色模式使用更深的棕黄以满足对比度。
    private var guidanceColor: Color {
        colorScheme == .dark
            ? Color(red: 0.98, green: 0.73, blue: 0.22)
            : Color(red: 0.58, green: 0.39, blue: 0.05)
    }

    /// 占位文案同时区分今天/历史和编辑/只读状态。
    private var placeholder: String {
        if isEditable {
            return isToday ? "输入今天的指引…" : "输入这一天的指引…"
        }
        return isToday ? "今天还没有指引" : "这一天还没有指引"
    }

    /// 明确使用中文公历日期和完整星期，避免系统区域设置导致格式不一致。
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter
    }()
}

// MARK: - UIKit 文本视图桥接

/// 把 UIKit `UITextView` 包装成 SwiftUI View。
///
/// 使用 UIKit 而不是 SwiftUI `TextEditor`，是为了让只读和编辑状态共享同一套 TextKit
/// 排版参数。这样切换编辑时每行字数不会跳变，同时能让高度随多行内容自动增长。
private struct GuidanceStyledTextView: UIViewRepresentable {
    @Binding var text: String
    let isEditable: Bool
    let textColor: UIColor

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    /// UIKit 视图只创建一次；之后的状态变化都走 `updateUIView`。
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        // 外层 ScrollView 负责整页滚动，内层关闭滚动后才能按内容计算完整高度。
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.textContainerInset = .zero
        // lineFragmentPadding 默认会偷偷增加左右留白；设为 0 才能保证显示/编辑换行一致。
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    /// SwiftUI 状态变化时，把文本、样式、可编辑性和光标状态同步到 UITextView。
    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        let attributes = textAttributes
        let selectedRange = textView.selectedRange

        if textView.text != text {
            // 仅当字符串真的变化时替换 attributedText，避免每次刷新都把光标移走。
            textView.attributedText = NSAttributedString(string: text, attributes: attributes)
        } else if !textView.text.isEmpty {
            textView.textStorage.setAttributes(
                attributes,
                range: NSRange(location: 0, length: textView.textStorage.length)
            )
        }

        textView.typingAttributes = attributes
        textView.isEditable = isEditable
        textView.isSelectable = true
        if isEditable && !context.coordinator.wasEditable {
            // 刚进入编辑时把光标放到末尾并自动弹出键盘。
            textView.selectedRange = NSRange(location: textView.textStorage.length, length: 0)
            DispatchQueue.main.async { textView.becomeFirstResponder() }
        } else if selectedRange.location <= textView.textStorage.length {
            textView.selectedRange = selectedRange
        }

        if !isEditable && context.coordinator.wasEditable {
            textView.resignFirstResponder()
        }
        context.coordinator.wasEditable = isEditable
    }

    /// iOS 16+ 的 UIViewRepresentable 自定义尺寸入口。
    ///
    /// 只读时高度刚好包住全文；编辑时至少 180 点，给用户足够的输入区域。
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let fittingHeight = uiView.sizeThatFits(CGSize(
            width: width,
            height: .greatestFiniteMagnitude
        )).height
        let font = textAttributes[.font] as? UIFont
        let minimumHeight = isEditable ? 180 : (font?.lineHeight ?? 24)
        return CGSize(width: width, height: ceil(max(fittingHeight, minimumHeight)))
    }

    /// 显示与输入共同使用的富文本属性；数据本身仍保存为纯文本。
    private var textAttributes: [NSAttributedString.Key: Any] {
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let paragraph = NSMutableParagraphStyle()
        // 稍紧的行距与正文字号更协调，保留轻松的阅读节奏。
        paragraph.lineSpacing = 5
        return [
            .font: baseFont,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]
    }

    /// UITextViewDelegate 不能直接由值类型 View 持有，Coordinator 充当长期存在的代理对象。
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GuidanceStyledTextView
        var wasEditable = false

        init(parent: GuidanceStyledTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            // 用户每次输入都回写 SwiftUI Binding，但文件仍要等顶栏“保存”才会修改。
            parent.text = textView.text
        }
    }
}

// MARK: - 按钮和品牌样式

/// 开始/暂停/继续/结束按钮共用的样式；`isProminent` 决定哪一个是当前主操作。
private struct SessionActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let isProminent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isProminent ? .headline : .subheadline.weight(.semibold))
            .padding(.vertical, 14)
            .foregroundStyle(isProminent ? Color.white : (isEnabled ? Color.primary : Color.secondary))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isProminent
                            ? Color.tomato.opacity(configuration.isPressed ? 0.78 : 1)
                            : Color.card.opacity(configuration.isPressed ? 0.65 : 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.45)
    }
}

/// 次要操作按钮样式，例如备注。
private struct QuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 14)
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.card.opacity(configuration.isPressed ? 0.65 : 1)))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

/// 只在本文件内使用的品牌色，避免把纯展示常量混入业务 Store。
private extension Color {
    static let tomato = Color(red: 0.89, green: 0.18, blue: 0.17)
    static let tomatoDark = Color(red: 0.62, green: 0.08, blue: 0.09)
    static let tomatoLight = Color(red: 1.0, green: 0.45, blue: 0.30)
    static let leaf = Color(red: 0.14, green: 0.54, blue: 0.30)
    static let card = Color(uiColor: .secondarySystemBackground)
}
