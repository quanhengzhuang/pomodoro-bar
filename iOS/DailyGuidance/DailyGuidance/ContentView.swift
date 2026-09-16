import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var store: GuidanceStore

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var isSelectingFile = false

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
                .navigationTitle("今日指引")
                .toolbar {
                    if store.hasSelectedFile {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                isSelectingFile = true
                            } label: {
                                Label("重新选择", systemImage: "doc.badge.gearshape")
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                store.refresh()
                            } label: {
                                Label("刷新", systemImage: "arrow.clockwise")
                            }
                        }
                    }
                }
        }
        .fileImporter(
            isPresented: $isSelectingFile,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else {
                return
            }
            store.selectFile(url)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active, store.hasSelectedFile {
                store.refresh()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .noFile:
            stateView(
                symbol: "icloud.and.arrow.down",
                title: "选择今日指引数据",
                message: "请从 iCloud Drive 的 PomodoroBar 文件夹中选择 daily-guidance.json。",
                actionTitle: "选择数据文件"
            ) {
                isSelectingFile = true
            }
        case .loading:
            ProgressView("正在读取今日指引…")
                .controlSize(.large)
        case .content(let guidance):
            guidanceView(guidance)
        case .empty:
            stateView(
                symbol: "sun.max",
                title: "今天还没有指引",
                message: selectedFileDescription,
                actionTitle: "刷新"
            ) {
                store.refresh()
            }
        case .error(let message):
            stateView(
                symbol: "exclamationmark.icloud",
                title: "无法显示今日指引",
                message: message,
                actionTitle: "重新选择数据文件"
            ) {
                isSelectingFile = true
            }
        }
    }

    private func guidanceView(_ guidance: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(todayDisplayText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 16) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(guidanceColor)
                        .frame(width: 4)

                    Text(guidance)
                        .font(.title3)
                        .italic()
                        .foregroundStyle(guidanceColor)
                        .lineSpacing(7)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(selectedFileDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .refreshable {
            store.refresh()
        }
    }

    private func stateView(
        symbol: String,
        title: String,
        message: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(guidanceColor)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(guidanceColor)
        }
        .padding(32)
    }

    private var guidanceColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.98, green: 0.73, blue: 0.22)
        }
        return Color(red: 0.58, green: 0.39, blue: 0.05)
    }

    private var selectedFileDescription: String {
        if let selectedFileName = store.selectedFileName {
            return "数据来源：\(selectedFileName)"
        }
        return "尚未选择数据文件"
    }

    private var todayDisplayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }
}
