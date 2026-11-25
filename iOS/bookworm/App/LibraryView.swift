import CoreTransferable
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct LibraryView: View {
    let store: LibraryStore
    @AppStorage("recentLibraryLayout") private var recentLayout = LibraryLayout.list
    @AppStorage("customLibraryLayout") private var customLayout = LibraryLayout.list
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: ReadingList = .custom
    @State private var sheet: LibrarySheet?
    @State private var shareDirectory: URL?
    @State private var pendingWidgetBook: ReadingWidgetBookLink?
    @State private var couldNotOpenWidgetBook = false

    var body: some View {
        TabView(selection: $selection) {
            ForEach([ReadingList.custom, .recent]) { list in
                LibraryScreen(
                    store: store,
                    list: list,
                    layout: list == .recent ? $recentLayout : $customLayout,
                    openSettings: { sheet = .settings },
                    openPicker: { sheet = .picker },
                    presentShare: { export in
                        shareDirectory = export.directory
                        sheet = .share(export)
                    }
                )
                .tabItem { Label(list.title, systemImage: list.iconName) }
                .tag(list)
            }
        }
        .sheet(item: $sheet, onDismiss: removeSharedImages) { destination in
            switch destination {
            case .settings: APIKeySettings(store: store)
            case .picker: ShelfPicker(store: store)
            case .share(let export): BookListShareSheet(files: export.files)
            }
        }
        .onOpenURL { url in
            let bookLink = ReadingWidgetBookLink(url: url)
            guard let list = bookLink?.list ?? ReadingList(openURL: url) else { return }
            sheet = nil
            selection = list
            pendingWidgetBook = bookLink
            openPendingWidgetBook()
        }
        .onChange(of: scenePhase) { openPendingWidgetBook() }
        .alert("无法打开微信读书", isPresented: $couldNotOpenWidgetBook) {
            Button("好", role: .cancel) {}
        } message: {
            Text("请确认已安装微信读书。")
        }
    }

    private func removeSharedImages() {
        if let shareDirectory { try? FileManager.default.removeItem(at: shareDirectory) }
        shareDirectory = nil
    }

    private func openPendingWidgetBook() {
        guard scenePhase == .active, let link = pendingWidgetBook else { return }
        pendingWidgetBook = nil

        let books = link.list == .recent ? store.recentBooks : store.customBooks
        let book = books.first { $0.id == link.bookID } ?? {
            let snapshot = WidgetSnapshotStore.load()
            let widgetBooks = link.list == .recent ? snapshot.recentBooks : snapshot.customBooks
            return widgetBooks.first { $0.id == link.bookID }
        }()
        guard let book else { return }
        let destinations = [book.readerURL, book.detailURL].compactMap { $0 }
        guard !destinations.isEmpty else { return }

        Task {
            let app = UIApplication.shared
            for url in destinations {
                switch url.scheme?.lowercased() {
                case "weread":
                    if await app.open(url) { return }
                case "https":
                    if await app.open(url, options: [.universalLinksOnly: true]) { return }
                default:
                    continue
                }
            }
            if let website = destinations.first(where: { $0.scheme?.lowercased() == "https" }),
               await app.open(website) { return }
            couldNotOpenWidgetBook = true
        }
    }
}

private enum LibrarySheet: Identifiable {
    case settings, picker
    case share(BookListShareExport)

    var id: String {
        switch self {
        case .settings: "settings"
        case .picker: "picker"
        case .share(let export): export.id.absoluteString
        }
    }
}

private enum LibraryLayout: String {
    case list, grid
}

private struct DraggedBook: Codable, Transferable {
    let id: String
    let session: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data).visibility(.ownProcess)
    }
}

private enum GridInsertionSide {
    case before, after
}

private struct GridInsertionTarget: Equatable {
    let bookID: String
    let side: GridInsertionSide
}

private struct LibraryScreen: View {
    let store: LibraryStore
    let list: ReadingList
    @Binding var layout: LibraryLayout
    let openSettings: () -> Void
    let openPicker: () -> Void
    let presentShare: (BookListShareExport) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @ScaledMetric(relativeTo: .caption) private var listCoverHeight: CGFloat = 84
    @State private var editMode = EditMode.inactive
    @State private var dragSession = UUID()
    @State private var insertionTarget: GridInsertionTarget?
    @State private var bookToRemove: ReadingBook?
    @State private var shareTask: Task<Void, Never>?
    @State private var shareFailed = false

    private let gridSpacing: CGFloat = 14
    private let gridRowSpacing: CGFloat = 16

    private var books: [ReadingBook] {
        list == .recent ? store.recentBooks : store.customBooks
    }

    private var isSorting: Bool { editMode.isEditing }

    var body: some View {
        NavigationStack {
            collection
                .scrollContentBackground(.hidden)
                .background(Color.readingShelfBackground.ignoresSafeArea())
                .environment(\.editMode, $editMode)
                .navigationTitle(list.title)
                .refreshable { await store.refresh() }
                .safeAreaInset(edge: .bottom, spacing: 0) { status }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("设置", systemImage: "gearshape", action: openSettings)
                            .disabled(isSorting || shareTask != nil)
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if isSorting {
                            Button("完成", action: finishEditing)
                        } else {
                            if list == .custom {
                                if shareTask != nil {
                                    ProgressView().accessibilityLabel("正在生成书单图片")
                                } else {
                                    Button("分享书单", systemImage: "square.and.arrow.up", action: generateShare)
                                        .disabled(books.isEmpty)
                                }
                                Button("添加书籍", systemImage: "plus", action: openPicker)
                                    .disabled(store.shelfBooks.isEmpty || shareTask != nil)
                            }
                            Button(
                                layout == .list ? "切换为格子" : "切换为列表",
                                systemImage: layout == .list ? "square.grid.2x2" : "list.bullet"
                            ) {
                                layout = layout == .list ? .grid : .list
                            }
                            .disabled(shareTask != nil)
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
        .alert("无法生成书单图片", isPresented: $shareFailed) {
            Button("好", role: .cancel) {}
        } message: {
            Text("请稍后重试。")
        }
        .onDisappear {
            finishEditing()
            shareTask?.cancel()
        }
    }

    private func generateShare() {
        guard shareTask == nil, !books.isEmpty else { return }
        let exportLayout: BookListShareLayout = layout == .list ? .list : .grid
        let items = books.map { book in
            BookListShareItem(book: book, details: details(for: book).shareDetails)
        }
        shareTask = Task {
            defer { shareTask = nil }
            do {
                let export = try await BookListShareRenderer.render(items: items, layout: exportLayout)
                guard !Task.isCancelled else {
                    try? FileManager.default.removeItem(at: export.directory)
                    return
                }
                presentShare(export)
            } catch {
                if !Task.isCancelled { shareFailed = true }
            }
        }
    }

    private func details(for book: ReadingBook) -> BookDetails {
        let metadata = store.bookMetadata(for: book.id)
        return BookDetails(
            book: book, progress: store.progress(for: book.id), recommendation: metadata?.recommendation,
            wordCount: metadata?.wordCount, compact: true
        )
    }

    @ViewBuilder
    private var collection: some View {
        let books = books
        let entries = Array(books.enumerated())
        if entries.isEmpty {
            ScrollView {
                emptyShelf.containerRelativeFrame([.horizontal, .vertical])
            }
            .scrollBounceBehavior(.always)
        } else if layout == .list {
            List {
                ForEach(entries, id: \.element.id) { index, book in
                    HStack(spacing: 10) {
                        BookCover(book: book, opensBook: !isSorting, onHold: list == .custom ? beginEditing : nil)
                            .frame(width: listCoverHeight * BookCover.aspectRatio, height: listCoverHeight)

                        details(for: book)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if list == .custom && !isSorting {
                            Menu {
                                bookActions(book, at: index, count: entries.count)
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .frame(width: 44, height: 44)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("《\(book.title)》的书单操作")
                        }
                    }
                    .contentShape(.rect)
                    .contextMenu {
                        if list == .recent { bookActions(book, at: index, count: entries.count) }
                    }
                    .simultaneousGesture(
                        LongPressGesture().onEnded { _ in beginEditing() },
                        including: list == .custom && !isSorting ? .all : .none
                    )
                    .moveDisabled(!isSorting)
                    .listRowInsets(EdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onMove(perform: list == .custom ? { offsets, destination in
                    moveListBook(at: offsets, toOffset: destination, displayedBooks: books)
                } : nil)
            }
            .listStyle(.plain)
        } else {
            let columnCount = dynamicTypeSize.isAccessibilitySize ? 1 : 4
            let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: gridSpacing), count: columnCount)
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: gridRowSpacing) {
                    ForEach(entries, id: \.element.id) { index, book in
                        gridBook(book, at: index, count: entries.count)
                    }
                }
                .padding(.horizontal, gridSpacing)
                .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private func gridBook(_ book: ReadingBook, at index: Int, count: Int) -> some View {
        let tile = VStack(alignment: .leading, spacing: 5) {
            BookCover(book: book, cornerRadius: 0, opensBook: !isSorting, onHold: list == .custom ? beginEditing : nil)
            Text(book.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)

        if isSorting {
            tile
                .overlay {
                    let halves = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
                    halves {
                        dropRegion(bookID: book.id, side: .before)
                        dropRegion(bookID: book.id, side: .after)
                    }
                }
                .draggable(DraggedBook(id: book.id, session: dragSession))
                .overlay {
                    if let insertionTarget, insertionTarget.bookID == book.id {
                        insertionLine(for: insertionTarget.side)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Menu {
                        bookActions(book, at: index, count: count)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption.weight(.semibold))
                            .frame(width: 30, height: 30)
                            .background(.regularMaterial, in: Circle())
                            .frame(width: 44, height: 44, alignment: .topTrailing)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .padding(3)
                    .accessibilityLabel("《\(book.title)》的书单操作")
                }
        } else if list == .custom {
            tile.simultaneousGesture(LongPressGesture().onEnded { _ in beginEditing() })
        } else {
            tile.contextMenu { bookActions(book, at: index, count: count) }
        }
    }

    private func dropRegion(bookID: String, side: GridInsertionSide) -> some View {
        let target = GridInsertionTarget(bookID: bookID, side: side)
        return Color.clear
            .contentShape(.rect)
            .accessibilityHidden(true)
            .dropDestination(for: DraggedBook.self) { items, _ in
                insertionTarget = nil
                guard items.count == 1, let item = items.first, item.session == dragSession else { return false }
                return moveBook(item.id, to: bookID, side: side)
            } isTargeted: { isTargeted in
                if isTargeted {
                    insertionTarget = target
                } else if insertionTarget == target {
                    insertionTarget = nil
                }
            }
    }

    private func insertionLine(for side: GridInsertionSide) -> some View {
        let singleColumn = dynamicTypeSize.isAccessibilitySize
        let before = side == .before
        let alignment: Alignment = singleColumn ? (before ? .top : .bottom) : (before ? .leading : .trailing)
        let sign: CGFloat = before ? -1 : 1
        let layoutSign: CGFloat = layoutDirection == .leftToRight ? 1 : -1
        let thickness: CGFloat = 3

        return Capsule()
            .fill(Color.accentColor)
            .frame(width: singleColumn ? nil : thickness, height: singleColumn ? thickness : nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .offset(
                x: singleColumn ? 0 : sign * layoutSign * (gridSpacing + thickness) / 2,
                y: singleColumn ? sign * (gridRowSpacing + thickness) / 2 : 0
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func beginEditing() {
        guard !isSorting, shareTask == nil else { return }
        dragSession = UUID()
        editMode = .active
    }

    private func finishEditing() {
        insertionTarget = nil
        editMode = .inactive
    }

    private func moveListBook(at offsets: IndexSet, toOffset destination: Int, displayedBooks: [ReadingBook]) {
        guard offsets.count == 1, let source = offsets.first, displayedBooks.indices.contains(source) else { return }
        // List's destination is an insertion point in the original list.
        let target = destination > source ? destination - 1 : destination
        guard displayedBooks.indices.contains(target) else { return }
        moveBook(displayedBooks[source].id, to: displayedBooks[target].id)
    }

    @discardableResult
    private func moveBook(_ id: String, to targetID: String, side: GridInsertionSide? = nil) -> Bool {
        let books = store.customBooks
        guard isSorting, list == .custom, id != targetID,
              let source = books.firstIndex(where: { $0.id == id }),
              let target = books.firstIndex(where: { $0.id == targetID }) else { return false }
        let destination: Int
        if let side {
            let boundary = target + (side == .after ? 1 : 0)
            destination = boundary - (source < boundary ? 1 : 0)
        } else {
            destination = target
        }
        guard destination != source else { return false }
        withAnimation { store.moveCustomBook(id, by: destination - source) }
        return store.customBooks[destination].id == id
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

    @ViewBuilder
    private func bookActions(_ book: ReadingBook, at index: Int, count: Int) -> some View {
        if store.hasAPIKey {
            let isLoading = store.isLoadingProgress(for: book.id)
            Button(isLoading ? "正在刷新阅读时长…" : "刷新阅读时长", systemImage: "arrow.clockwise") {
                Task { await store.loadProgress(for: book.id) }
            }
            .disabled(isLoading)
            .accessibilityHint(store.progressError(for: book.id) ?? "")
        }
        if list == .custom {
            Button("上移", systemImage: "chevron.up") { store.moveCustomBook(book.id, by: -1) }
                .disabled(index == 0)
            Button("下移", systemImage: "chevron.down") { store.moveCustomBook(book.id, by: 1) }
                .disabled(index == count - 1)
            Button("移出", systemImage: "minus.circle", role: .destructive) { bookToRemove = book }
        }
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

private struct BookListShareSheet: UIViewControllerRepresentable {
    let files: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let providers = files.compactMap { NSItemProvider(contentsOf: $0) }
        let configuration = UIActivityItemsConfiguration(itemProviders: providers)
        return UIActivityViewController(activityItemsConfiguration: configuration)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct BookCover: View {
    static let aspectRatio: CGFloat = 0.7

    @Environment(\.openURL) private var openURL
    let book: ReadingBook
    var cornerRadius: CGFloat = 5
    var opensBook = true
    var onHold: (() -> Void)?

    var body: some View {
        if opensBook, let url = book.destinationURL {
            if let onHold {
                artwork
                    .gesture(LongPressGesture().exclusively(before: TapGesture()).onEnded { gesture in
                        switch gesture {
                        case .first(true): onHold()
                        case .second: openURL(url)
                        default: break
                        }
                    })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("打开《\(book.title)》")
                    .accessibilityAddTraits(.isLink)
                    .accessibilityAction { openURL(url) }
                    .accessibilityAction(named: Text("编辑书单"), onHold)
            } else {
                Link(destination: url) { artwork }
                    .buttonStyle(.plain)
                    .accessibilityLabel("打开《\(book.title)》")
            }
        } else {
            artwork.accessibilityHidden(true)
        }
    }

    private var artwork: some View {
        Rectangle()
            .fill(Color.accentColor.opacity(0.09))
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .overlay {
                AsyncImage(url: book.coverURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "book.closed").foregroundStyle(.tint)
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .contentShape(.rect)
    }
}

private struct BookDetails: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let book: ReadingBook
    var progress: ReadingProgress?
    var recommendation: Double?
    var wordCount: Int?
    var compact = false

    private static let dateFormat = Date.ISO8601FormatStyle(timeZone: .autoupdatingCurrent)
        .year().month().day().dateSeparator(.dash)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.title).font(compact ? .footnote.weight(.semibold) : .headline)
                .lineLimit(compact ? 1 : 2)
            if let author = book.author, !author.isEmpty {
                Text(author).font(compact ? .caption : .subheadline).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            ForEach(metadataLines, id: \.self) { line in
                if dynamicTypeSize.isAccessibilitySize {
                    Text(line.joined(separator: "，"))
                } else {
                    HStack(spacing: 7) {
                        Text(line[0])
                        if let second = line.dropFirst().first {
                            Rectangle()
                                .fill(Color.primary.opacity(0.085))
                                .frame(width: 1, height: 10)
                                .accessibilityHidden(true)
                            Text(second)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .accessibilityElement(children: .combine)
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    var shareDetails: [String] {
        [book.author].compactMap { $0 }.filter { !$0.isEmpty } +
            metadataLines.map { $0.joined(separator: "  |  ") }
    }

    private var metadataLines: [[String]] {
        let catalog = [recommendationText, wordCountText].compactMap { $0 }
        let reading = [lastReadText, readingTimeText].compactMap { $0 }
        return [catalog, reading].filter { !$0.isEmpty }
    }

    private var recommendationText: String? {
        guard let recommendation else { return nil }
        let percent = (recommendation / 100).formatted(.percent.precision(.fractionLength(0...1)))
        return "推荐值 \(percent)"
    }

    private var wordCountText: String? {
        guard let wordCount else { return nil }
        if wordCount < 10_000 { return "\(wordCount.formatted()) 字" }
        let tenThousands = (Double(wordCount) / 10_000).formatted(.number.precision(.fractionLength(0...1)))
        return "\(tenThousands) 万字"
    }

    private var lastReadText: String? {
        guard let date = [progress?.lastReadAt, book.lastReadAt].compactMap({ $0 }).max() else { return nil }
        return date.formatted(Self.dateFormat)
    }

    private var readingTimeText: String? {
        guard let seconds = progress?.totalReadingSeconds, seconds > 0 else { return nil }
        return "累计 \(Self.duration(seconds))"
    }

    private static func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes == 0 { return "\(seconds) 秒" }
        if minutes < 60 { return "\(minutes) 分钟" }
        return "\(minutes / 60) 小时 \(minutes % 60) 分钟"
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
