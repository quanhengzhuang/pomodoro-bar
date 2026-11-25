import SwiftUI

struct LibraryView: View {
    let store: LibraryStore
    @AppStorage("recentLibraryLayout") private var recentLayout = LibraryLayout.list
    @AppStorage("customLibraryLayout") private var customLayout = LibraryLayout.list
    @State private var selection: ReadingList? = .recent
    @State private var showsShelfPicker = false

    private var activeList: ReadingList { selection ?? .recent }
    private var layout: Binding<LibraryLayout> { activeList == .recent ? $recentLayout : $customLayout }
    private var books: [ReadingBook] { activeList == .recent ? store.recentBooks : store.customBooks }
    private var canRefresh: Bool { store.hasAPIKey && !store.isRefreshing && !store.isSavingAPIKey }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(ReadingList.allCases) { list in
                    Label(list.title, systemImage: list.iconName)
                        .tag(list)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 150, ideal: 176, max: 214)
        } detail: {
            listContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(activeList.title)
                .safeAreaInset(edge: .bottom, spacing: 0) { syncStatus }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("布局", selection: layout) {
                            Label("列表", systemImage: "list.bullet").tag(LibraryLayout.list)
                            Label("格子", systemImage: "square.grid.2x2").tag(LibraryLayout.grid)
                        }
                        .labelsHidden()
                        .labelStyle(.iconOnly)
                        .pickerStyle(.segmented)
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        if activeList == .custom {
                            Button("添加书籍", systemImage: "plus") { showsShelfPicker = true }
                                .disabled(store.shelfBooks.isEmpty)
                        }
                        Button("刷新书架", systemImage: "arrow.clockwise", action: refresh)
                            .keyboardShortcut("r", modifiers: .command)
                            .disabled(!canRefresh)

                        SettingsLink { Label("设置", systemImage: "gearshape") }
                    }
                }
        }
        .sheet(isPresented: $showsShelfPicker) {
            ShelfPicker(store: store)
        }
        .onOpenURL { url in
            if let list = ReadingList(openURL: url) {
                showsShelfPicker = false
                selection = list
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if !books.isEmpty {
            bookCollection
        } else if !store.hasAPIKey && store.shelfBooks.isEmpty {
            ContentUnavailableView {
                Label("连接微信读书", systemImage: "books.vertical")
            } description: {
                Text("输入微信读书 API Key，查看你的书架。")
            } actions: {
                SettingsLink { Text("打开设置") }
            }
        } else if store.isRefreshing && store.lastSyncedAt == nil {
            ProgressView("正在同步书架…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.errorMessage != nil && store.lastSyncedAt == nil && store.shelfBooks.isEmpty {
            ContentUnavailableView {
                Label("书架暂时无法同步", systemImage: "arrow.clockwise.circle")
            } actions: {
                Button("重新同步", action: refresh)
                    .disabled(!canRefresh)
            }
        } else if activeList == .recent {
            ContentUnavailableView(
                "没有最近阅读",
                systemImage: activeList.iconName,
                description: Text("同步后，这里会显示书架里读过的书。")
            )
        } else {
            ContentUnavailableView {
                Label("书单还没有书", systemImage: activeList.iconName)
            } description: {
                Text(store.shelfBooks.isEmpty ? "同步有书籍的微信读书书架后，即可选书。" : "从微信读书书架选择想加入的书。")
            } actions: {
                if !store.shelfBooks.isEmpty {
                    Button("从书架选书") { showsShelfPicker = true }
                }
            }
        }
    }

    @ViewBuilder
    private var bookCollection: some View {
        let entries = Array(books.enumerated())
        switch layout.wrappedValue {
        case .list:
            List {
                ForEach(entries, id: \.element.id) { index, book in
                    BookRow(book: book, progress: store.progress(for: book.id)) {
                        bookActions(for: book, at: index)
                    }
                }
            }
            .listStyle(.inset)
        case .grid:
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 132, maximum: 178), spacing: 18, alignment: .topLeading)],
                    alignment: .leading,
                    spacing: 24
                ) {
                    ForEach(entries, id: \.element.id) { index, book in
                        VStack(alignment: .leading, spacing: 6) {
                            BookCover(book: book)
                                .frame(width: 60)
                            BookHeading(book: book, reservesTitleSpace: true)
                            BookMetrics(book: book, progress: store.progress(for: book.id))
                            HStack(spacing: 10) { bookActions(for: book, at: index) }
                                .buttonStyle(.borderless)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
        }
    }

    private func refresh() {
        Task { await store.refresh() }
    }

    @ViewBuilder
    private func bookActions(for book: ReadingBook, at index: Int) -> some View {
        ReadingDataButton(store: store, book: book)
        if activeList == .custom {
            customActions(for: book, at: index)
        }
    }

    private func customActions(for book: ReadingBook, at index: Int) -> some View {
        Group {
            Button { store.moveCustomBook(book.id, by: -1) } label: { Image(systemName: "chevron.up") }
                .help("上移")
                .accessibilityLabel("上移《\(book.title)》")
                .disabled(index == 0)
            Button { store.moveCustomBook(book.id, by: 1) } label: { Image(systemName: "chevron.down") }
                .help("下移")
                .accessibilityLabel("下移《\(book.title)》")
                .disabled(index == books.count - 1)
            Button { store.removeFromCustomList(book.id) } label: { Image(systemName: "minus.circle") }
                .help("移出自定义书单")
                .accessibilityLabel("将《\(book.title)》移出自定义书单")
        }
    }

    @ViewBuilder
    private var syncStatus: some View {
        let error = store.errorMessage ?? store.cacheErrorMessage ?? store.widgetErrorMessage
        if store.isRefreshing || store.lastSyncedAt != nil || error != nil || store.upgradeMessage != nil {
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    if store.isRefreshing {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text("正在同步书架…")
                        }
                    } else if let time = store.lastSyncedAt {
                        Label {
                            Text("上次同步 \(time.formatted(.dateTime.month().day().hour().minute()))")
                        } icon: {
                            Image(systemName: "checkmark.circle")
                        }
                    }
                    if let error {
                        WarningLabel(message: error)
                    } else if let upgrade = store.upgradeMessage {
                        Label(upgrade, systemImage: "info.circle")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(.bar)
        }
    }
}

private enum LibraryLayout: String {
    case list, grid
}

private struct ShelfPicker: View {
    let store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var matches: [ReadingBook] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return store.shelfBooks }
        return store.shelfBooks.filter {
            $0.title.localizedStandardContains(term) || $0.author?.localizedStandardContains(term) == true
        }
    }

    var body: some View {
        let added = Set(store.customBooks.map(\.id))
        let books = matches
        VStack(alignment: .leading, spacing: 10) {
            Text("从书架选书")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 16)

            TextField("搜索书名或作者", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)

            if books.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(books) { book in
                    BookRow(book: book) {
                        if added.contains(book.id) {
                            Label("已添加", systemImage: "checkmark")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Button("添加") { store.addToCustomList(book.id) }
                                .accessibilityLabel("添加《\(book.title)》")
                        }
                    }
                }
                .listStyle(.inset)
            }

            HStack {
                if let error = store.cacheErrorMessage ?? store.widgetErrorMessage {
                    WarningLabel(message: error)
                        .font(.caption)
                }
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .frame(width: 460, height: 410)
    }
}

private struct WarningLabel: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.orange)
        }
    }
}

private struct BookRow<Actions: View>: View {
    let book: ReadingBook
    var progress: ReadingProgress?
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(spacing: 12) {
            BookCover(book: book)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                BookHeading(book: book)
                BookMetrics(book: book, progress: progress)
            }

            Spacer(minLength: 8)
            HStack(spacing: 9, content: actions)
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

private struct BookCover: View {
    let book: ReadingBook

    var body: some View {
        if let url = book.destinationURL {
            let action = book.readerURL == url ? "打开阅读" : "查看详情"
            Link(destination: url) { artwork }
                .buttonStyle(.plain)
                .help(action)
                .accessibilityLabel("\(action)《\(book.title)》")
        } else {
            artwork.accessibilityHidden(true)
        }
    }

    private var artwork: some View {
        Rectangle()
            .fill(Color.indigo.opacity(0.12))
            .aspectRatio(0.7, contentMode: .fit)
            .overlay {
                AsyncImage(url: book.coverURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "book.closed")
                        .foregroundStyle(Color.indigo)
                }
            }
            .clipShape(.rect(cornerRadius: 3))
            .contentShape(.rect)
    }
}

private struct BookHeading: View {
    let book: ReadingBook
    var reservesTitleSpace = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(book.title)
                .font(.body.weight(.medium))
                .lineLimit(2, reservesSpace: reservesTitleSpace)
            if let author = book.author, !author.isEmpty {
                Text(author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct BookMetrics: View {
    let book: ReadingBook
    let progress: ReadingProgress?

    private static let readingDateFormat = Date.ISO8601FormatStyle(timeZone: .current)
        .year().month().day().dateSeparator(.dash)

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let seconds = progress?.elapsedSeconds {
                Text("累计 \(duration(seconds))")
            }
            if let date = [progress?.lastReadAt, book.lastReadAt].compactMap({ $0 }).max() {
                Text("最近阅读 \(date.formatted(Self.readingDateFormat))")
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes < 1 { return "\(seconds) 秒" }
        if minutes < 60 { return "\(minutes) 分钟" }
        return "\(minutes / 60) 小时 \(minutes % 60) 分钟"
    }
}

private struct ReadingDataButton: View {
    let store: LibraryStore
    let book: ReadingBook
    @State private var isShowingData = false

    var body: some View {
        Button {
            isShowingData = true
            if store.progress(for: book.id) == nil { loadProgress() }
        } label: {
            Image(systemName: "clock")
        }
        .help("查看阅读数据")
        .accessibilityLabel("查看《\(book.title)》的阅读数据")
        .popover(isPresented: $isShowingData) {
            let progress = store.progress(for: book.id)
            VStack(alignment: .leading, spacing: 8) {
                Text(book.title).font(.headline)
                BookMetrics(book: book, progress: progress)
                if store.isLoadingProgress(for: book.id) {
                    ProgressView("正在获取阅读数据…").controlSize(.small)
                } else if let error = store.progressError(for: book.id) {
                    WarningLabel(message: error)
                } else if store.hasAPIKey && progress?.elapsedSeconds == nil {
                    Text("暂无累计阅读时长").foregroundStyle(.secondary)
                }
                if store.hasAPIKey {
                    Button("刷新阅读数据", action: loadProgress)
                        .disabled(store.isLoadingProgress(for: book.id))
                } else {
                    SettingsLink { Text("打开设置") }
                }
            }
            .padding(14)
            .frame(width: 238, alignment: .leading)
        }
    }

    private func loadProgress() {
        guard store.hasAPIKey else { return }
        Task { await store.loadProgress(for: book.id) }
    }
}
