import SwiftUI

struct LibraryView: View {
    let store: LibraryStore
    @State private var selection: ReadingList? = .recent
    @State private var showsShelfPicker = false

    private var activeList: ReadingList { selection ?? .recent }
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
            List {
                ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                    BookRow(book: book, showsReadingDate: activeList == .recent) {
                        if let url = book.destinationURL {
                            let title = book.readerURL == url ? "打开阅读" : "查看详情"
                            Link(destination: url) { Image(systemName: "arrow.up.right.square") }
                                .help(title)
                                .accessibilityLabel("\(title)《\(book.title)》")
                        }
                        if activeList == .custom {
                            customActions(for: book, at: index)
                        }
                    }
                }
            }
            .listStyle(.inset)
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

    private func refresh() {
        Task { await store.refresh() }
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
    var showsReadingDate = false
    @ViewBuilder var actions: () -> Actions

    private static var readingDateFormat: Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(timeZone: .current).year().month().day().dateSeparator(.dash)
    }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: book.coverURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "book.closed")
                    .font(.caption)
                    .foregroundStyle(Color.indigo)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.indigo.opacity(0.12))
            }
            .frame(width: 31, height: 44)
            .clipShape(.rect(cornerRadius: 3))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                if let author = book.author, !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)

            if showsReadingDate, let date = book.lastReadAt {
                Text(date, format: Self.readingDateFormat)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            HStack(spacing: 9, content: actions)
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
