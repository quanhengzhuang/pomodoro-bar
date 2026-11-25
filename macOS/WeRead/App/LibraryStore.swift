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
    private var canSaveCache = true
    private var didStart = false

    var hasAPIKey: Bool { credential != nil }
    var lastSyncedAt: Date? { library.lastSyncedAt }
    var shelfBooks: [ReadingBook] { library.shelfBooks }
    var recentBooks: [ReadingBook] { library.recentBooks }
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
            apply(shelf, credentialID: credential.id)
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
            apply(shelf, credentialID: savedCredential.id)
            return true
        } catch {
            if !Task.isCancelled { apiKeyErrorMessage = syncErrorMessage(for: error) }
            return false
        }
    }

    func clearAPIKeyError() {
        apiKeyErrorMessage = nil
    }

    func addToCustomList(_ id: String) {
        guard let book = shelfBooks.first(where: { $0.id == id }),
              !customBooks.contains(where: { $0.id == id }) else { return }
        saveCustomBooks(customBooks + [book])
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

    private func apply(_ shelf: WeReadAPI.Shelf, credentialID: UUID) {
        var updated = library
        updated.credentialID = credentialID
        updated.shelfBooks = shelf.books
        updated.lastSyncedAt = Date()
        let shelfByID = Dictionary(uniqueKeysWithValues: shelf.books.map { ($0.id, $0) })
        updated.customBooks = updated.customBooks.map { shelfByID[$0.id] ?? $0 }
        saveCache(updated)
        library = updated
        upgradeMessage = shelf.hasSkillUpgrade ? "微信读书 Skill 有新版本。" : nil
        publishWidgets()
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
        do {
            try WidgetSnapshotStore.save(ReadingWidgetSnapshot(
                recentBooks: Array(recentBooks.prefix(4)),
                customBooks: Array(customBooks.prefix(4)),
                lastSyncedAt: lastSyncedAt
            ))
            widgetErrorMessage = nil
            WidgetCenter.shared.reloadTimelines(ofKind: ReadingList.recent.widgetKind)
            WidgetCenter.shared.reloadTimelines(ofKind: ReadingList.custom.widgetKind)
        } catch {
            widgetErrorMessage = "无法更新桌面小组件，请检查应用和扩展的 App Group 设置。"
        }
    }

    private func syncErrorMessage(for error: Error) -> String {
        if let failure = error as? WeReadAPI.Failure { return failure.localizedDescription }
        if error is APIKeyRecord.StorageFailure { return "无法将 API Key 保存到钥匙串。" }
        return "暂时无法连接微信读书，请检查网络后重试。"
    }
}

private struct CachedLibrary: Codable {
    var credentialID: UUID?
    var shelfBooks: [ReadingBook] = []
    var customBooks: [ReadingBook] = []
    var lastSyncedAt: Date?

    var recentBooks: [ReadingBook] {
        shelfBooks.compactMap { book in book.lastReadAt.map { (book: book, readAt: $0) } }
            .sorted { $0.readAt > $1.readAt }
            .map(\.book)
    }

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
