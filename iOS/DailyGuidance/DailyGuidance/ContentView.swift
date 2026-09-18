import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var store: PomodoroStore
    @ObservedObject var guidanceStore: GuidanceStore

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize = 56
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if guidanceStore.hasSelectedFile {
                            guidanceStore.refresh()
                            isShowingGuidance = true
                        } else {
                            isSelectingGuidance = true
                        }
                    } label: {
                        Image(systemName: "quote.opening")
                    }
                    .accessibilityLabel("今日指引")
                }
            }
        }
        .tint(.tomato)
        .fileImporter(
            isPresented: $isSelectingGuidance,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
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
                .disabled(store.hasActiveSession)
                .opacity(store.hasActiveSession && store.selectedMode != mode ? 0.45 : 1)
            }
        }
    }

    private var timerFace: some View {
        ZStack {
            Circle()
                .stroke(Color.tomato.opacity(0.12), lineWidth: 22)

            Circle()
                .trim(from: 0, to: max(0.002, store.progress))
                .stroke(
                    AngularGradient(colors: [.tomatoDark, .tomato, .tomatoLight, .tomato], center: .center),
                    style: StrokeStyle(lineWidth: 22, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: store.progress)

            ForEach(0..<8, id: \.self) { index in
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
        .accessibilityLabel("\(store.selectedMode.title)，\(formattedTime(store.displaySeconds))，\(statusText)")
    }

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

    private var background: some View {
        LinearGradient(
            colors: [Color(uiColor: .systemBackground), Color.tomato.opacity(0.035)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

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

private struct GuidanceSheet: View {
    @ObservedObject var store: GuidanceStore
    let selectAnotherFile: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var draftGuidance = ""
    @State private var editingDateKey: String?
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
            draftGuidance = store.todayGuidance
        }
        .onChange(of: store.todayGuidance) { guidance in
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

    private func stateView(symbol: String, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 40, weight: .light)).foregroundStyle(guidanceColor)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("选择数据文件", action: selectAnotherFile).buttonStyle(.borderedProminent)
        }
        .padding(30)
    }

    private var guidanceColor: Color {
        colorScheme == .dark
            ? Color(red: 0.98, green: 0.73, blue: 0.22)
            : Color(red: 0.58, green: 0.39, blue: 0.05)
    }

    private var canEditGuidance: Bool {
        switch store.state {
        case .content, .empty:
            return store.hasSelectedFile
        case .noFile, .loading, .error:
            return false
        }
    }

    private var isEditing: Bool {
        editingDateKey != nil
    }

    private func beginEditing(_ dateKey: String, _ guidance: String) {
        draftGuidance = guidance
        editingOriginalGuidance = guidance
        editingDateKey = dateKey
    }

    private func finishEditing() {
        editingDateKey = nil
        editingOriginalGuidance = ""
        draftGuidance = store.todayGuidance
    }
}

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

    private var pastEntries: [GuidanceHistoryEntry] {
        store.historyEntries.filter { $0.dateKey != store.todayDateKey }
    }

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

private struct GuidanceEntryCard: View {
    let date: Date
    @Binding var guidance: String
    let isEditable: Bool
    let isToday: Bool
    let onEdit: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Self.dateFormatter.string(from: date))
                    .font(.headline)
                Spacer()
                if isToday {
                    Text("今天")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(guidanceColor)
                } else if let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "square.and.pencil")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(guidanceColor)
                    .accessibilityLabel("编辑\(Self.dateFormatter.string(from: date))的指引")
                }
            }

            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(guidanceColor)
                    .frame(width: 4)

                ZStack(alignment: .topLeading) {
                    GuidanceStyledTextView(
                        text: $guidance,
                        isEditable: isEditable,
                        textColor: UIColor(guidanceColor)
                    )

                    if guidance.isEmpty {
                        Text(placeholder)
                            .font(.title3)
                            .italic()
                            .foregroundStyle(isEditable ? guidanceColor.opacity(0.48) : Color.secondary)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.card))
    }

    private var guidanceColor: Color {
        colorScheme == .dark
            ? Color(red: 0.98, green: 0.73, blue: 0.22)
            : Color(red: 0.58, green: 0.39, blue: 0.05)
    }

    private var placeholder: String {
        if isEditable {
            return isToday ? "输入今天的指引…" : "输入这一天的指引…"
        }
        return isToday ? "今天还没有指引" : "这一天还没有指引"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter
    }()
}

private struct GuidanceStyledTextView: UIViewRepresentable {
    @Binding var text: String
    let isEditable: Bool
    let textColor: UIColor

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        let attributes = textAttributes
        let selectedRange = textView.selectedRange

        if textView.text != text {
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

    private var textAttributes: [NSAttributedString.Key: Any] {
        let baseFont = UIFont.preferredFont(forTextStyle: .title3)
        let italicFont = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic)
            .map { UIFont(descriptor: $0, size: 0) } ?? baseFont
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 7
        return [
            .font: italicFont,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GuidanceStyledTextView
        var wasEditable = false

        init(parent: GuidanceStyledTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

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

private extension Color {
    static let tomato = Color(red: 0.89, green: 0.18, blue: 0.17)
    static let tomatoDark = Color(red: 0.62, green: 0.08, blue: 0.09)
    static let tomatoLight = Color(red: 1.0, green: 0.45, blue: 0.30)
    static let leaf = Color(red: 0.14, green: 0.54, blue: 0.30)
    static let card = Color(uiColor: .secondarySystemBackground)
}
