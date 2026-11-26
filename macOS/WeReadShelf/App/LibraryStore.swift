import Foundation
import Observation
import Security
import WidgetKit

@MainActor
@Observable
final class LibraryStore {
    private(set) var isRefreshing = false
    private(set) var isSavingAPIKey = false
    private(set) var errorMessage: String?
    private(set) var apiKeyErrorMessage: String?
    private(set) var cacheErrorMessage: String?
    private(set) var widgetErrorMessage: String?
    private(set) var upgradeMessage: String?

    private let api = WeReadAPI()
    private var credential: APIKeyRecord?
    private var library = CachedLibrary()
    private var progressRequests: [String: Task<Void, Never>] = [:]
    private var progressErrors: [String: String] = [:]
    @ObservationIgnored private var automaticProgressTask: Task<Void, Never>?
    @ObservationIgnored private var automaticProgressQueue: [AutomaticBookRequest] = []
    @ObservationIgnored private var activeAutomaticRequest: AutomaticBookRequest?
#if os(iOS)
    @ObservationIgnored private var widgetCoverTask: Task<Void, Never>?
#endif
    private var canSaveCache = true
    private var didStart = false

    var hasAPIKey: Bool { credential != nil }
    var lastSyncedAt: Date? { library.lastSyncedAt }
    var shelfBooks: [ReadingBook] {
        library.shelfBooks.sorted { ($0.lastReadAt ?? .distantPast) > ($1.lastReadAt ?? .distantPast) }
    }
    var recentBooks: [ReadingBook] { shelfBooks.filter { $0.lastReadAt != nil } }
    var customBooks: [ReadingBook] { library.customBooks }

    init() {
        do {
            credential = try APIKeyRecord.load()
        } catch {
            apiKeyErrorMessage = "无法读取钥匙串中的 API Key。"
        }
        do {
            library = try CachedLibrary.load()
        } catch {
            canSaveCache = false
            cacheErrorMessage = "无法读取本机书单，请重新打开应用后重试。"
        }

        // A key change may have succeeded while writing the shelf cache failed.
        if let credential, library.credentialID != credential.id {
            library.shelfBooks = []
            library.lastSyncedAt = nil
            library.readingProgress = nil
            library.bookMetadata = nil
            library.customBooks = library.customBooks.map(\.withoutLastReadDate)
        }
    }

    func start() async {
        guard !didStart else { return }
        didStart = true
        if canSaveCache, library.credentialID != nil || !customBooks.isEmpty { publishWidgets() }
        await refresh()
        if Task.isCancelled { didStart = false }
    }

    func refresh() async {
        guard let credential, !isRefreshing, !isSavingAPIKey else { return }
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        do {
            let shelf = try await api.fetchShelf(apiKey: credential.key)
            try Task.checkCancellation()
            apply(shelf, credential: credential)
        } catch {
            if !Task.isCancelled { errorMessage = syncErrorMessage(for: error) }
        }
    }

    func saveAPIKey(_ input: String) async -> Bool {
        guard !isRefreshing, !isSavingAPIKey else { return false }
        clearAPIKeyError()
        let key = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.hasPrefix("wrk-"), key.count > 4, key.utf8.allSatisfy({ (33...126).contains($0) }) else {
            apiKeyErrorMessage = "请输入以 wrk- 开头的微信读书 API Key。"
            return false
        }

        isSavingAPIKey = true
        defer { isSavingAPIKey = false }
        do {
            let shelf = try await api.fetchShelf(apiKey: key)
            try Task.checkCancellation()
            let existingCredential = credential.flatMap { $0.key == key ? $0 : nil }
            let savedCredential = existingCredential ?? APIKeyRecord(id: UUID(), key: key)
            try savedCredential.save()
            credential = savedCredential
            errorMessage = nil
            apply(shelf, credential: savedCredential)
            return true
        } catch {
            if !Task.isCancelled { apiKeyErrorMessage = syncErrorMessage(for: error) }
            return false
        }
    }

    func clearAPIKeyError() {
        apiKeyErrorMessage = nil
    }

    func progress(for bookID: String) -> ReadingProgress? {
        guard let credential, credential.id == library.credentialID else { return nil }
        return library.readingProgress?[bookID]
    }

    func bookMetadata(for bookID: String) -> BookMetadata? {
        guard let credential, credential.id == library.credentialID else { return nil }
        return library.bookMetadata?[bookID]?.value
    }

    func isLoadingProgress(for bookID: String) -> Bool {
        progressRequests[bookID] != nil
    }

    func progressError(for bookID: String) -> String? {
        progressErrors[bookID]
    }

    func loadProgress(for bookID: String) async {
        guard let credential, credential.id == library.credentialID,
              library.shelfBooks.contains(where: { $0.id == bookID }) ||
                  customBooks.contains(where: { $0.id == bookID }) else { return }
        if let request = progressRequests[bookID] {
            await request.value
            return
        }

        progressErrors[bookID] = nil
        let request = Task { [weak self] in
            guard let self else { return }
            await self.fetchProgress(for: bookID, credential: credential)
        }
        progressRequests[bookID] = request
        await request.value
    }

    func addToCustomList(_ id: String) {
        guard let book = shelfBooks.first(where: { $0.id == id }),
              !customBooks.contains(where: { $0.id == id }) else { return }
        saveCustomBooks(customBooks + [book])
#if os(iOS)
        enqueueAutomaticProgress(refreshCached: false)
#endif
    }

    func removeFromCustomList(_ id: String) {
        let books = customBooks.filter { $0.id != id }
        guard books.count != customBooks.count else { return }
        saveCustomBooks(books)
    }

    func moveCustomBook(_ id: String, by offset: Int) {
        guard offset != 0, let index = customBooks.firstIndex(where: { $0.id == id }) else { return }
        let (destination, overflow) = index.addingReportingOverflow(offset)
        guard !overflow, customBooks.indices.contains(destination) else { return }
        var books = customBooks
        let book = books.remove(at: index)
        books.insert(book, at: destination)
        saveCustomBooks(books)
    }

    private func apply(_ shelf: WeReadAPI.Shelf, credential: APIKeyRecord) {
        var updated = library
        if updated.credentialID != credential.id {
            automaticProgressTask?.cancel()
            automaticProgressTask = nil
            automaticProgressQueue.removeAll()
            activeAutomaticRequest = nil
            for request in progressRequests.values { request.cancel() }
            progressRequests.removeAll()
            progressErrors.removeAll()
            updated.readingProgress = nil
            updated.bookMetadata = nil
            updated.customBooks = updated.customBooks.map(\.withoutLastReadDate)
        }
        updated.credentialID = credential.id
        updated.shelfBooks = shelf.books
        updated.lastSyncedAt = Date()
        let shelfByID = Dictionary(uniqueKeysWithValues: shelf.books.map { ($0.id, $0) })
        updated.customBooks = updated.customBooks.map { shelfByID[$0.id] ?? $0 }
        saveCache(updated)
        library = updated
        upgradeMessage = shelf.hasSkillUpgrade ? "微信读书 Skill 有新版本。" : nil
        publishWidgets()
        enqueueAutomaticProgress(refreshCached: true)
    }

    private func enqueueAutomaticProgress(refreshCached: Bool) {
        guard let credential, credential.id == library.credentialID else { return }
#if os(iOS)
        let books = customBooks + recentBooks
        let now = Date.now
#else
        let books = Array(recentBooks.prefix(5))
#endif
        var seen = Set<String>()
        let pendingProgress = Set(automaticProgressQueue.filter(\.refreshProgress).map(\.bookID))
        let requests = books.compactMap { book -> AutomaticBookRequest? in
            let bookID = book.id
            guard seen.insert(bookID).inserted else { return nil }
            let isActive = activeAutomaticRequest?.bookID == bookID
            let progressRequested = progressRequests[bookID] != nil ||
                (isActive && activeAutomaticRequest?.refreshProgress == true)
            let refreshProgress = !progressRequested &&
                (refreshCached || pendingProgress.contains(bookID) || library.readingProgress?[bookID] == nil)
#if os(iOS)
            let refreshMetadata = !isActive && needsBookMetadata(for: bookID, at: now)
#else
            let refreshMetadata = false
#endif
            guard refreshProgress || refreshMetadata else { return nil }
            return AutomaticBookRequest(bookID: bookID, refreshProgress: refreshProgress)
        }
        automaticProgressQueue = Array(requests.reversed())
        guard automaticProgressTask == nil, !automaticProgressQueue.isEmpty else { return }
        let credentialID = credential.id
        automaticProgressTask = Task { [weak self] in
            while !Task.isCancelled, let self, let credential = self.credential, credential.id == credentialID,
                  let request = self.automaticProgressQueue.popLast() {
                self.activeAutomaticRequest = request
                if request.refreshProgress {
                    await self.loadProgress(for: request.bookID)
#if os(iOS)
                    try? await Task.sleep(for: .milliseconds(250))
#endif
                }
#if os(iOS)
                if !Task.isCancelled, self.needsBookMetadata(for: request.bookID, at: .now) {
                    await self.fetchBookMetadata(for: request.bookID, credential: credential)
                    try? await Task.sleep(for: .milliseconds(250))
                }
#endif
            }
            if !Task.isCancelled {
                self?.activeAutomaticRequest = nil
                self?.automaticProgressTask = nil
            }
        }
    }

#if os(iOS)
    private func needsBookMetadata(for bookID: String, at now: Date) -> Bool {
        guard let cached = library.bookMetadata?[bookID] else { return true }
        return now.timeIntervalSince(cached.fetchedAt) >= 24 * 60 * 60 || now < cached.fetchedAt ||
            (cached.value.wordCount == nil && cached.didCheckChapters != true) ||
            (cached.value.publicReaderCount == nil && cached.didCheckPublicPage != true)
    }

    private func fetchBookMetadata(for bookID: String, credential: APIKeyRecord) async {
        guard let metadata = try? await api.fetchBookMetadata(bookID: bookID, apiKey: credential.key),
              !Task.isCancelled, self.credential?.id == credential.id else { return }
        let cached = library.bookMetadata?[bookID]?.value
        let book = library.shelfBooks.first { $0.id == bookID } ?? customBooks.first { $0.id == bookID }
        var publicMetadata: WeReadAPI.PublicBookMetadata?
        var didCheckPublicPage = true
        if let book, !book.isPrivate {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, self.credential?.id == credential.id else { return }
            do {
                publicMetadata = try await api.fetchPublicBookMetadata(
                    bookID: bookID, links: [book.detailURL, metadata.detailURL, book.readerURL, cached?.detailURL]
                )
            } catch {
                didCheckPublicPage = false
            }
        }

        let exactWordCount = metadata.wordCount ?? publicMetadata?.wordCount
        var wordCount = exactWordCount ?? cached?.wordCount
        var approximate = exactWordCount == nil ? cached?.wordCountIsApproximate : nil
        var didCheckChapters = true
        if wordCount == nil {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, self.credential?.id == credential.id else { return }
            do {
                wordCount = try await api.fetchChapterWordCount(bookID: bookID, apiKey: credential.key)
                approximate = wordCount == nil ? nil : true
            } catch {
                didCheckChapters = false
            }
        }

        guard !Task.isCancelled, self.credential?.id == credential.id else { return }
        let value = BookMetadata(
            recommendation: metadata.recommendation ?? cached?.recommendation, wordCount: wordCount,
            publicReaderCount: publicMetadata?.readerCount ?? cached?.publicReaderCount, wordCountIsApproximate: approximate,
            detailURL: metadata.detailURL ?? cached?.detailURL
        )
        var updated = library
        if updated.bookMetadata == nil { updated.bookMetadata = [:] }
        updated.bookMetadata?[bookID] = CachedBookMetadata(
            value: value, fetchedAt: .now, didCheckChapters: didCheckChapters,
            didCheckPublicPage: didCheckPublicPage
        )
        saveCache(updated)
        library = updated
    }
#endif

    private func fetchProgress(for bookID: String, credential: APIKeyRecord) async {
        defer {
            if self.credential?.id == credential.id {
                progressRequests[bookID] = nil
            }
        }

        do {
            let progress = try await api.fetchProgress(bookID: bookID, apiKey: credential.key)
            try Task.checkCancellation()
            guard self.credential?.id == credential.id else { return }

            var updated = library
            if updated.readingProgress == nil { updated.readingProgress = [:] }
            updated.readingProgress?[bookID] = progress
            saveCache(updated)
            library = updated
        } catch {
            if !Task.isCancelled, self.credential?.id == credential.id {
                progressErrors[bookID] = syncErrorMessage(for: error)
            }
        }
    }

    private func saveCustomBooks(_ books: [ReadingBook]) {
        var updated = library
        updated.customBooks = books
        guard saveCache(updated) else { return }
        library = updated
        publishWidgets()
    }

    @discardableResult
    private func saveCache(_ updated: CachedLibrary) -> Bool {
        guard canSaveCache else { return false }
        do {
            try updated.save()
            cacheErrorMessage = nil
            return true
        } catch {
            cacheErrorMessage = "无法将书单保存到本机，请稍后重试。"
            return false
        }
    }

    private func publishWidgets() {
        let snapshot = ReadingWidgetSnapshot(
            recentBooks: Array(recentBooks.prefix(4)),
            customBooks: Array(customBooks.prefix(4)),
            lastSyncedAt: lastSyncedAt
        )
        do {
            try WidgetSnapshotStore.save(snapshot)
            widgetErrorMessage = nil
            Self.reloadWidgets()
#if os(iOS)
            widgetCoverTask?.cancel()
            widgetCoverTask = Task {
                if await WidgetSnapshotStore.prefetchCovers(for: snapshot), !Task.isCancelled {
                    WidgetSnapshotStore.trimCoverCache(keeping: snapshot)
                    Self.reloadWidgets()
                }
            }
#endif
        } catch {
            widgetErrorMessage = "无法更新桌面小组件，请检查应用和扩展的 App Group 设置。"
        }
    }

    private static func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: ReadingList.recent.widgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: ReadingList.custom.widgetKind)
    }

    private func syncErrorMessage(for error: Error) -> String {
        if let failure = error as? WeReadAPI.Failure { return failure.localizedDescription }
        if error is APIKeyRecord.StorageFailure { return "无法将 API Key 保存到钥匙串。" }
        return "暂时无法连接微信读书，请检查网络后重试。"
    }
}

private extension ReadingBook {
    var withoutLastReadDate: ReadingBook {
        ReadingBook(
            id: id, title: title, author: author, coverURL: coverURL,
            readerURL: readerURL, detailURL: detailURL, lastReadAt: nil, isPrivate: isPrivate
        )
    }
}

private struct AutomaticBookRequest {
    let bookID: String
    let refreshProgress: Bool
}

private struct CachedBookMetadata: Codable {
    let value: BookMetadata
    let fetchedAt: Date
    let didCheckChapters: Bool?
    let didCheckPublicPage: Bool?
}

private struct CachedLibrary: Codable {
    var credentialID: UUID?
    var shelfBooks: [ReadingBook] = []
    var customBooks: [ReadingBook] = []
    var lastSyncedAt: Date?
    var readingProgress: [String: ReadingProgress]?
    var bookMetadata: [String: CachedBookMetadata]?

    private static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "WeRead/library.json")
    }

    static func load() throws -> Self {
        do {
            return try JSONDecoder().decode(Self.self, from: Data(contentsOf: fileURL))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return Self()
        }
    }

    func save() throws {
        let url = Self.fileURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}

private struct APIKeyRecord: Codable {
    let id: UUID
    let key: String

    struct StorageFailure: Error {}

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "WeRead",
            kSecAttrAccount as String: "WeRead API Key"
        ]
    }

    static func load() throws -> Self? {
        var query = Self.query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw StorageFailure() }
        return try JSONDecoder().decode(Self.self, from: data)
    }

    func save() throws {
        let values = [kSecValueData as String: try JSONEncoder().encode(self)]
        var status = SecItemUpdate(Self.query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            let item = Self.query.merging(values) { _, new in new }
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw StorageFailure() }
    }
}
