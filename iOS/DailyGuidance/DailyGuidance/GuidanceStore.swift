// iOS“今日指引”的数据层。
//
// CloudKit Private Database 是设备间的主同步通道；Application Support 中的
// daily-guidance.json 仍以可读 JSON 形式保留为离线缓存和备份。用户曾经选择的
// iCloud Drive JSON 也不会被删除，可继续作为可见导出副本。
import Combine
import Foundation

/// 今日指引页面的顶层加载状态。
enum GuidanceViewState: Equatable {
    /// 保留旧状态以兼容界面分支；CloudKit 版本正常不再要求先选文件。
    case noFile
    case loading
    case content(String)
    case empty
    case error(String)
}

/// 时间流中的一天。
struct GuidanceHistoryEntry: Identifiable, Equatable {
    let dateKey: String
    let date: Date
    let guidance: String
    var id: String { dateKey }
}

/// 纯文本与单条修改时间分开保存，使用户仍能直接阅读原 JSON。
private struct GuidanceMetadata: Codable {
    var modifiedAtByDate: [String: Date]
}

/// 管理 CloudKit 指引、本地 JSON 备份和历史页面状态。
@MainActor
final class GuidanceStore: ObservableObject {
    @Published private(set) var state: GuidanceViewState = .loading
    @Published private(set) var selectedFileName: String?
    @Published private(set) var todayGuidance = ""
    @Published private(set) var historyEntries: [GuidanceHistoryEntry] = []
    @Published private(set) var saveErrorMessage: String?

    private let cloudStore = PomodoroCloudKitStore()
    private let bookmarkStorageKey = "daily-guidance-file-bookmark"
    private let legacyBackupKey = "ios.cloudkit.guidance-backup-created"
    private var selectedFileURL: URL?
    private var guidanceByDate: [String: String] = [:]
    private var modifiedAtByDate: [String: Date] = [:]
    private var isSynchronizingCloud = false
    private var cloudMigrationAllowed = true

    private var dataDirectoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PomodoroBar", isDirectory: true)
    }

    private var cacheURL: URL {
        dataDirectoryURL.appendingPathComponent("daily-guidance.json")
    }

    private var metadataURL: URL {
        dataDirectoryURL.appendingPathComponent("daily-guidance-metadata.json")
    }

    private lazy var dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()

    /// 表示是否保留了一个用户可见的旧 JSON 副本，不再决定页面能否编辑。
    var hasSelectedFile: Bool { selectedFileURL != nil }

    init() {
        restoreSelectedFile()
        loadLocalCache()
        if guidanceByDate.isEmpty {
            let importedLegacyFile = importSelectedLegacyFile(reportErrors: false)
            if importedLegacyFile, !guidanceByDate.isEmpty {
                do {
                    try saveLocalFiles()
                } catch {
                    cloudMigrationAllowed = false
                    saveErrorMessage = "无法保存旧指引的本机副本，已停止 CloudKit 迁移。"
                }
            }
        }
        if cloudMigrationAllowed {
            cloudMigrationAllowed = backupLegacyDataIfNeeded()
        }
        apply(guidanceByDate)
        Task { await synchronizeWithCloud(reportErrors: false) }
    }

    // MARK: - 旧 JSON 导入与本地刷新

    /// 选择旧 daily-guidance.json 时会立即备份、导入并合并到 CloudKit。
    func selectFile(_ url: URL) {
        do {
            let bookmark = try withSecurityScopedAccess(to: url) {
                try url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            }
            UserDefaults.standard.set(bookmark, forKey: bookmarkStorageKey)
            selectedFileURL = url
            selectedFileName = url.lastPathComponent
            guard backupFile(url, label: "selected-daily-guidance") else {
                state = .error("无法备份所选数据文件，已停止导入以保护原数据。")
                return
            }
            guard importSelectedLegacyFile(reportErrors: true) else { return }
            try saveLocalFiles()
            apply(guidanceByDate)
            Task { await synchronizeWithCloud(reportErrors: true) }
        } catch {
            state = .error("无法保存文件访问权限：\(error.localizedDescription)")
        }
    }

    /// 先重读本地缓存，立即展示；随后异步从 CloudKit 合并新数据。
    func refresh() {
        loadLocalCache()
        apply(guidanceByDate)
        Task { await synchronizeWithCloud(reportErrors: false) }
    }

    // MARK: - 保存

    /// 本地先原子落盘，再异步上传 CloudKit；断网时用户刚输入的文本不会丢失。
    @discardableResult
    func saveGuidance(_ guidance: String, forDateKey dateKey: String) -> Bool {
        guard let parsedDate = dateKeyFormatter.date(from: dateKey),
              dateKeyFormatter.string(from: parsedDate) == dateKey else {
            saveErrorMessage = "指引日期格式无效。"
            return false
        }

        let previousText = guidanceByDate[dateKey]
        let previousModifiedAt = modifiedAtByDate[dateKey]
        guidanceByDate[dateKey] = guidance.trimmingCharacters(in: .whitespacesAndNewlines)
        modifiedAtByDate[dateKey] = Date()

        do {
            try saveLocalFiles()
            mirrorToSelectedFileIfPossible()
            saveErrorMessage = nil
            apply(guidanceByDate)
            let entry = CloudDailyGuidance(
                dateKey: dateKey,
                text: guidanceByDate[dateKey] ?? "",
                modifiedAt: modifiedAtByDate[dateKey] ?? Date()
            )
            Task { await upload(entry, reportErrors: true) }
            return true
        } catch {
            guidanceByDate[dateKey] = previousText
            modifiedAtByDate[dateKey] = previousModifiedAt
            saveErrorMessage = "指引暂时无法保存，原数据未被删除。"
            return false
        }
    }

    func clearSaveError() {
        saveErrorMessage = nil
    }

    /// 只忘记旧文件的导出授权；CloudKit 与 App 内本地备份均保留。
    func forgetSelectedFile() {
        selectedFileURL = nil
        selectedFileName = nil
        UserDefaults.standard.removeObject(forKey: bookmarkStorageKey)
    }

    // MARK: - CloudKit 合并

    private func synchronizeWithCloud(reportErrors: Bool) async {
        guard cloudMigrationAllowed, !isSynchronizingCloud else { return }
        isSynchronizingCloud = true
        defer { isSynchronizingCloud = false }

        do {
            let cloudEntries = try await cloudStore.fetchGuidance()
            for entry in cloudEntries {
                let localDate = modifiedAtByDate[entry.dateKey] ?? .distantPast
                if entry.modifiedAt > localDate {
                    guidanceByDate[entry.dateKey] = entry.text
                    modifiedAtByDate[entry.dateKey] = entry.modifiedAt
                }
            }

            try saveLocalFiles()
            mirrorToSelectedFileIfPossible()
            try await cloudStore.saveGuidance(cloudGuidanceEntries())
            saveErrorMessage = nil
            apply(guidanceByDate)
        } catch {
            // 有本地内容时继续展示，不用临时网络错误遮住整个页面。
            if reportErrors {
                saveErrorMessage = "iCloud 数据暂时无法同步，本机 JSON 备份已保留。"
            } else if guidanceByDate.isEmpty {
                state = .error("无法读取 iCloud 数据，请确认已登录 iCloud 并稍后重试。")
            }
        }
    }

    private func upload(_ entry: CloudDailyGuidance, reportErrors: Bool) async {
        do {
            try await cloudStore.saveGuidance([entry])
            saveErrorMessage = nil
        } catch {
            if reportErrors {
                saveErrorMessage = "指引已保存在本机，但 iCloud 暂时未同步。"
            }
        }
    }

    private func cloudGuidanceEntries() -> [CloudDailyGuidance] {
        guidanceByDate.map { dateKey, text in
            CloudDailyGuidance(
                dateKey: dateKey,
                text: text,
                modifiedAt: modifiedAtByDate[dateKey] ?? .distantPast
            )
        }
    }

    // MARK: - JSON 缓存、元数据与备份

    private func loadLocalCache() {
        if let data = try? Data(contentsOf: cacheURL),
           let values = try? JSONDecoder().decode([String: String].self, from: data) {
            guidanceByDate = values
        }
        if let data = try? Data(contentsOf: metadataURL),
           let metadata = try? JSONDecoder().decode(GuidanceMetadata.self, from: data) {
            modifiedAtByDate = metadata.modifiedAtByDate
        }

        let fallbackDate = modificationDate(of: cacheURL)
        for dateKey in guidanceByDate.keys where modifiedAtByDate[dateKey] == nil {
            modifiedAtByDate[dateKey] = fallbackDate
        }
    }

    /// 显式选择的旧文件会以文件修改时间作为首次迁移时间。
    @discardableResult
    private func importSelectedLegacyFile(reportErrors: Bool) -> Bool {
        guard let selectedFileURL else { return false }
        do {
            let (data, modifiedAt) = try withSecurityScopedAccess(to: selectedFileURL) {
                let data = try Data(contentsOf: selectedFileURL)
                return (data, modificationDate(of: selectedFileURL))
            }
            let values = try JSONDecoder().decode([String: String].self, from: data)
            for (dateKey, text) in values
            where modifiedAt >= (modifiedAtByDate[dateKey] ?? .distantPast) {
                guidanceByDate[dateKey] = text
                modifiedAtByDate[dateKey] = modifiedAt
            }
            return true
        } catch {
            if reportErrors {
                state = .error("所选 JSON 无法读取，原文件未被修改。")
            }
            return false
        }
    }

    private func saveLocalFiles() throws {
        try FileManager.default.createDirectory(at: dataDirectoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        var guidanceData = try encoder.encode(guidanceByDate)
        guidanceData.append(0x0A)
        try guidanceData.write(to: cacheURL, options: .atomic)

        var metadataData = try encoder.encode(GuidanceMetadata(modifiedAtByDate: modifiedAtByDate))
        metadataData.append(0x0A)
        try metadataData.write(to: metadataURL, options: .atomic)
    }

    /// 已授权的 iCloud Drive JSON 继续作为人工可读副本；写入失败不影响主缓存。
    private func mirrorToSelectedFileIfPossible() {
        guard let selectedFileURL else { return }
        do {
            try withSecurityScopedAccess(to: selectedFileURL) {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                var data = try encoder.encode(guidanceByDate)
                data.append(0x0A)
                try data.write(to: selectedFileURL, options: .atomic)
            }
        } catch {
            // 选定文件是额外副本，不能因它暂时未下载就否定本地和 CloudKit 保存。
        }
    }

    /// 首次 CloudKit 迁移前复制 App 缓存和用户所选原文件。
    private func backupLegacyDataIfNeeded() -> Bool {
        if UserDefaults.standard.bool(forKey: legacyBackupKey) { return true }
        var allSucceeded = true
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            allSucceeded = backupFile(cacheURL, label: "cached-daily-guidance") && allSucceeded
        }
        // security-scoped URL 在授权作用域外的 fileExists 结果不可靠，直接在 backupFile 内访问。
        if let selectedFileURL {
            allSucceeded = backupFile(selectedFileURL, label: "selected-daily-guidance") && allSucceeded
        }
        if allSucceeded {
            UserDefaults.standard.set(true, forKey: legacyBackupKey)
        } else {
            saveErrorMessage = "无法备份原指引文件，已停止 CloudKit 迁移。"
        }
        return allSucceeded
    }

    private func backupFile(_ sourceURL: URL, label: String) -> Bool {
        do {
            let backupDirectory = dataDirectoryURL.appendingPathComponent("Legacy Backups", isDirectory: true)
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
            let targetURL = backupDirectory.appendingPathComponent(
                "\(label)-before-cloudkit-\(formatter.string(from: Date())).json"
            )
            if sourceURL == selectedFileURL {
                try withSecurityScopedAccess(to: sourceURL) {
                    try FileManager.default.copyItem(at: sourceURL, to: targetURL)
                }
            } else {
                try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            }
            return true
        } catch {
            return false
        }
    }

    private func modificationDate(of url: URL) -> Date {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date ?? .distantPast
    }

    // MARK: - Security-scoped bookmark

    private func restoreSelectedFile() {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkStorageKey) else { return }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            selectedFileURL = url
            selectedFileName = url.lastPathComponent
            if isStale {
                let renewedBookmark = try withSecurityScopedAccess(to: url) {
                    try url.bookmarkData(
                        options: .minimalBookmark,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                }
                UserDefaults.standard.set(renewedBookmark, forKey: bookmarkStorageKey)
            }
        } catch {
            // 失效书签只影响额外 JSON 副本，不清空 CloudKit/本地缓存。
            selectedFileURL = nil
            selectedFileName = nil
        }
    }

    private func withSecurityScopedAccess<T>(
        to url: URL,
        operation: () throws -> T
    ) rethrows -> T {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }
        return try operation()
    }

    // MARK: - 日期与派生状态

    var todayDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    var todayDateKey: String {
        dateKeyFormatter.string(from: Date())
    }

    private func apply(_ values: [String: String]) {
        let guidance = values[todayDateKey] ?? ""
        todayGuidance = guidance
        historyEntries = recentHistory(from: values)
        state = guidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .empty
            : .content(guidance)
    }

    private func recentHistory(from values: [String: String]) -> [GuidanceHistoryEntry] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: Date())
        guard let earliestDate = calendar.date(byAdding: .day, value: -29, to: today) else {
            return []
        }

        return values.compactMap { dateKey, guidance in
            guard !guidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let parsedDate = dateKeyFormatter.date(from: dateKey),
                  dateKeyFormatter.string(from: parsedDate) == dateKey else {
                return nil
            }
            let date = calendar.startOfDay(for: parsedDate)
            guard date >= earliestDate, date <= today else { return nil }
            return GuidanceHistoryEntry(dateKey: dateKey, date: date, guidance: guidance)
        }
        .sorted { $0.date > $1.date }
    }
}
