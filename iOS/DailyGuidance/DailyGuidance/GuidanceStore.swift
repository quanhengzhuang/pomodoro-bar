import Combine
import Foundation

enum GuidanceViewState: Equatable {
    case noFile
    case loading
    case content(String)
    case empty
    case error(String)
}

struct GuidanceHistoryEntry: Identifiable, Equatable {
    let dateKey: String
    let date: Date
    let guidance: String

    var id: String { dateKey }
}

@MainActor
final class GuidanceStore: ObservableObject {
    @Published private(set) var state: GuidanceViewState = .noFile
    @Published private(set) var selectedFileName: String?
    @Published private(set) var todayGuidance = ""
    @Published private(set) var historyEntries: [GuidanceHistoryEntry] = []
    @Published private(set) var saveErrorMessage: String?

    private let bookmarkStorageKey = "daily-guidance-file-bookmark"
    private var selectedFileURL: URL?
    private lazy var dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()

    var hasSelectedFile: Bool {
        selectedFileURL != nil
    }

    init() {
        restoreSelectedFile()
    }

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
            refresh()
        } catch {
            state = .error("无法保存文件访问权限：\(error.localizedDescription)")
        }
    }

    func refresh() {
        guard let selectedFileURL else {
            todayGuidance = ""
            historyEntries = []
            state = .noFile
            return
        }

        state = .loading

        do {
            let data = try withSecurityScopedAccess(to: selectedFileURL) {
                try Data(contentsOf: selectedFileURL)
            }
            let guidanceByDate = try JSONDecoder().decode([String: String].self, from: data)
            apply(guidanceByDate)
        } catch let error as DecodingError {
            todayGuidance = ""
            historyEntries = []
            state = .error("数据文件格式无效：\(decodingErrorDescription(error))")
        } catch {
            todayGuidance = ""
            historyEntries = []
            state = .error("无法读取数据文件，请确认文件仍在 iCloud Drive 中。")
        }
    }

    @discardableResult
    func saveTodayGuidance(_ guidance: String) -> Bool {
        guard let selectedFileURL else {
            saveErrorMessage = "请先选择 daily-guidance.json。"
            return false
        }

        do {
            let guidanceByDate = try withSecurityScopedAccess(to: selectedFileURL) {
                let data = try Data(contentsOf: selectedFileURL)
                var values = try JSONDecoder().decode([String: String].self, from: data)
                values[todayDateKey] = guidance.trimmingCharacters(in: .whitespacesAndNewlines)

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                var updatedData = try encoder.encode(values)
                updatedData.append(0x0A)
                try updatedData.write(to: selectedFileURL, options: .atomic)
                return values
            }

            saveErrorMessage = nil
            apply(guidanceByDate)
            return true
        } catch let error as DecodingError {
            saveErrorMessage = "数据文件格式无效：\(decodingErrorDescription(error))"
        } catch {
            saveErrorMessage = "无法写入数据文件，请确认 iCloud 文件已下载且仍可访问。"
        }
        return false
    }

    func clearSaveError() {
        saveErrorMessage = nil
    }

    func forgetSelectedFile() {
        selectedFileURL = nil
        selectedFileName = nil
        todayGuidance = ""
        historyEntries = []
        saveErrorMessage = nil
        UserDefaults.standard.removeObject(forKey: bookmarkStorageKey)
        state = .noFile
    }

    private func restoreSelectedFile() {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkStorageKey) else {
            return
        }

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
            refresh()
        } catch {
            forgetSelectedFile()
            state = .error("之前选择的数据文件已无法访问，请重新选择。")
        }
    }

    private func withSecurityScopedAccess<T>(
        to url: URL,
        operation: () throws -> T
    ) rethrows -> T {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }

    var todayDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    var todayDateKey: String {
        dateKeyFormatter.string(from: Date())
    }

    private func apply(_ guidanceByDate: [String: String]) {
        let guidance = guidanceByDate[todayDateKey] ?? ""
        saveErrorMessage = nil
        todayGuidance = guidance
        historyEntries = recentHistory(from: guidanceByDate)
        state = guidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .empty
            : .content(guidance)
    }

    private func recentHistory(from guidanceByDate: [String: String]) -> [GuidanceHistoryEntry] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let today = calendar.startOfDay(for: Date())
        guard let earliestDate = calendar.date(byAdding: .day, value: -29, to: today) else {
            return []
        }

        return guidanceByDate.compactMap { dateKey, guidance in
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

    private func decodingErrorDescription(_ error: DecodingError) -> String {
        switch error {
        case .dataCorrupted:
            return "内容不是有效的 JSON"
        case .keyNotFound, .typeMismatch, .valueNotFound:
            return "内容不是日期到文字的对应表"
        @unknown default:
            return "无法解析内容"
        }
    }
}
