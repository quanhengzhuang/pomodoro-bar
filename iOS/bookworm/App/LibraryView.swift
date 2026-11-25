import SwiftUI

struct LibraryView: View {
    let store: LibraryStore
    @AppStorage("recentLibraryLayout") private var recentLayout = LibraryLayout.list
    @AppStorage("customLibraryLayout") private var customLayout = LibraryLayout.list
    @State private var selection: ReadingList = .recent
    @State private var sheet: LibrarySheet?

    var body: some View {
        TabView(selection: $selection) {
            ForEach(ReadingList.allCases) { list in
                LibraryScreen(
                    store: store,
                    list: list,
                    layout: list == .recent ? $recentLayout : $customLayout,
                    openSettings: { sheet = .settings },
                    openPicker: { sheet = .picker }
                )
                .tabItem { Label(list.title, systemImage: list.iconName) }
                .tag(list)
            }
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .settings: APIKeySettings(store: store)
            case .picker: ShelfPicker(store: store)
            }
        }
        .onOpenURL { url in
            guard let list = ReadingList(openURL: url) else { return }
            sheet = nil
            selection = list
        }
    }
}

private enum LibrarySheet: String, Identifiable {
    case settings, picker

    var id: Self { self }
}

private enum LibraryLayout: String {
    case list, grid
}

private struct LibraryScreen: View {
    let store: LibraryStore
    let list: ReadingList
    @Binding var layout: LibraryLayout
    let openSettings: () -> Void
    let openPicker: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var bookToRemove: ReadingBook?

    private var books: [ReadingBook] {
        list == .recent ? store.recentBooks : store.customBooks
    }

    var body: some View {
        NavigationStack {
            collection
                .navigationTitle(list.title)
                .refreshable { await store.refresh() }
                .safeAreaInset(edge: .bottom, spacing: 0) { status }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("设置", systemImage: "gearshape", action: openSettings)
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if list == .custom {
                            Button("添加书籍", systemImage: "plus", action: openPicker)
                                .disabled(store.shelfBooks.isEmpty)
                        }
                        Button(
                            layout == .list ? "切换为格子" : "切换为列表",
                            systemImage: layout == .list ? "square.grid.2x2" : "list.bullet"
                        ) {
                            layout = layout == .list ? .grid : .list
                        }
                    }
                }
                .alert(
                    "从「\(list.title)」移出？",
                    isPresented: Binding(
                        get: { bookToRemove != nil },
                        set: { if !$0 { bookToRemove = nil } }
                    ),
                    presenting: bookToRemove
                ) { book in
                    Button("取消", role: .cancel) {}
                    Button("移出", role: .destructive) { store.removeFromCustomList(book.id) }
                } message: { book in
                    Text("《\(book.title)》")
                }
        }
    }

    @ViewBuilder
    private var collection: some View {
        let entries = Array(books.enumerated())
        if entries.isEmpty {
            ScrollView {
                emptyShelf.containerRelativeFrame([.horizontal, .vertical])
            }
            .scrollBounceBehavior(.always)
        } else if layout == .list {
            List {
                ForEach(entries, id: \.element.id) { index, book in
                    HStack(alignment: .top, spacing: 12) {
                        BookCover(book: book).frame(width: 46)
                        BookDetails(book: book, progress: store.progress(for: book.id))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        actions(book, at: index, count: entries.count)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        } else {
            let columns = dynamicTypeSize.isAccessibilitySize
                ? [GridItem(.flexible())]
                : [GridItem(.adaptive(minimum: 104), spacing: 14, alignment: .topLeading)]
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                    ForEach(entries, id: \.element.id) { index, book in
                        VStack(alignment: .leading, spacing: 7) {
                            BookCover(book: book)
                            BookDetails(book: book, progress: store.progress(for: book.id))
                            actions(book, at: index, count: entries.count)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var emptyShelf: some View {
        if !store.hasAPIKey {
            ContentUnavailableView {
                Label("连接微信读书", systemImage: "books.vertical")
            } description: {
                Text("输入微信读书 API Key 后同步书架。")
            } actions: {
                Button("打开设置", action: openSettings).buttonStyle(.borderedProminent)
            }
        } else if store.isRefreshing {
            ProgressView("正在同步书架…")
        } else if store.errorMessage != nil && store.lastSyncedAt == nil {
            ContentUnavailableView {
                Label("书架暂时无法同步", systemImage: "arrow.clockwise.circle")
            } actions: {
                Button("重试") { Task { await store.refresh() } }.buttonStyle(.bordered)
            }
        } else if list == .custom && !store.shelfBooks.isEmpty {
            ContentUnavailableView {
                Label("书单还没有书", systemImage: list.iconName)
            } actions: {
                Button("从书架选书", action: openPicker).buttonStyle(.borderedProminent)
            }
        } else {
            ContentUnavailableView(
                list == .recent ? "没有最近阅读" : "书单还没有书",
                systemImage: list.iconName,
                description: Text("下拉可刷新微信读书书架。")
            )
        }
    }

    private func actions(_ book: ReadingBook, at index: Int, count: Int) -> some View {
        HStack(spacing: 0) {
            if store.hasAPIKey {
                ReadingTimeButton(store: store, book: book)
            }
            if list == .custom {
                Menu {
                    Button("上移", systemImage: "chevron.up") { store.moveCustomBook(book.id, by: -1) }
                        .disabled(index == 0)
                    Button("下移", systemImage: "chevron.down") { store.moveCustomBook(book.id, by: 1) }
                        .disabled(index == count - 1)
                    Button("移出", systemImage: "minus.circle", role: .destructive) { bookToRemove = book }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel("《\(book.title)》的书单操作")
            }
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private var status: some View {
        let error = store.errorMessage ?? store.cacheErrorMessage ?? store.widgetErrorMessage
        if let message = error ?? store.upgradeMessage {
            Label(message, systemImage: error == nil ? "info.circle" : "exclamationmark.circle")
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(.regularMaterial)
        }
    }
}

private struct BookCover: View {
    let book: ReadingBook

    var body: some View {
        if let url = book.destinationURL {
            Link(destination: url) { artwork }
                .buttonStyle(.plain)
                .accessibilityLabel("打开《\(book.title)》")
        } else {
            artwork.accessibilityHidden(true)
        }
    }

    private var artwork: some View {
        Rectangle()
            .fill(Color.accentColor.opacity(0.09))
            .aspectRatio(0.7, contentMode: .fit)
            .overlay {
                AsyncImage(url: book.coverURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "book.closed").foregroundStyle(.tint)
                }
            }
            .clipShape(.rect(cornerRadius: 5))
            .contentShape(.rect)
    }
}

private struct BookDetails: View {
    let book: ReadingBook
    var progress: ReadingProgress?

    private static let dateFormat = Date.ISO8601FormatStyle(timeZone: .autoupdatingCurrent)
        .year().month().day().dateSeparator(.dash)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.title).font(.headline).lineLimit(2)
            if let author = book.author, !author.isEmpty {
                Text(author).font(.subheadline).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let seconds = progress?.totalReadingSeconds, seconds > 0 {
                Text("累计 \(duration(seconds))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if let date = [progress?.lastReadAt, book.lastReadAt].compactMap({ $0 }).max() {
                Text("最近阅读 \(date.formatted(Self.dateFormat))")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }

    private func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes == 0 { return "\(seconds) 秒" }
        if minutes < 60 { return "\(minutes) 分钟" }
        return "\(minutes / 60) 小时 \(minutes % 60) 分钟"
    }
}

private struct ReadingTimeButton: View {
    let store: LibraryStore
    let book: ReadingBook

    var body: some View {
        let isLoading = store.isLoadingProgress(for: book.id)
        let error = store.progressError(for: book.id)
        Button {
            Task { await store.loadProgress(for: book.id) }
        } label: {
            Group {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: error == nil ? "clock" : "exclamationmark.circle")
                        .foregroundStyle(error == nil ? Color.accentColor : Color.orange)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(.rect)
        }
        .disabled(isLoading)
        .accessibilityLabel("刷新《\(book.title)》的阅读时长")
        .accessibilityHint(error ?? "")
        .accessibilityValue(isLoading ? "正在刷新" : "")
    }
}

private struct ShelfPicker: View {
    let store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var visibleBooks: [ReadingBook] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let books = store.shelfBooks
        guard !term.isEmpty else { return books }
        return books.filter {
            $0.title.localizedStandardContains(term) || $0.author?.localizedStandardContains(term) == true
        }
    }

    var body: some View {
        let books = visibleBooks
        let selectedIDs = Set(store.customBooks.map(\.id))
        NavigationStack {
            List(books) { book in
                HStack(alignment: .top, spacing: 12) {
                    BookCover(book: book).frame(width: 40)
                    BookDetails(book: book)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if selectedIDs.contains(book.id) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .accessibilityLabel("已添加")
                    } else {
                        Button {
                            store.addToCustomList(book.id)
                        } label: {
                            Image(systemName: "plus.circle")
                                .frame(width: 44, height: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("添加《\(book.title)》")
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if books.isEmpty { ContentUnavailableView.search(text: query) }
            }
            .searchable(text: $query, prompt: "搜索书名或作者")
            .navigationTitle("从书架选书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
    }
}
