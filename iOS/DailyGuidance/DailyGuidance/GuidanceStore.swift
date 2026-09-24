// iOS“今日指引”的数据层。
//
// 这个 Store 不负责界面布局；它负责保存用户通过文件选择器授予的 iCloud 文件权限、
// 读取/写入 daily-guidance.json、生成今天的内容和近 30 天时间流，并把错误转换为可展示状态。
import Combine
import Foundation

/// 今日指引页面的顶层加载状态。
///
/// 使用枚举而不是多个 Bool，可以避免“既在加载又显示错误”之类互相矛盾的组合。
enum GuidanceViewState: Equatable {
    /// 尚未选择数据文件。
    case noFile
    /// 正在读取已授权文件。
    case loading
    /// 今天有非空内容；关联值是当天原始文本。
    case content(String)
    /// 文件可读，但今天没有内容。
    case empty
    /// 授权、读取或 JSON 解析失败；关联值是面向用户的说明。
    case error(String)
}

/// 时间流中的一天。
struct GuidanceHistoryEntry: Identifiable, Equatable {
    /// JSON 使用的稳定 key，例如 `2026-09-18`。
    let dateKey: String
    /// 已按本地时区归一到当天零点的日期，用于排序和界面格式化。
    let date: Date
    /// 保留换行的纯文本指引。
    let guidance: String

    /// SwiftUI `ForEach` 需要稳定 ID；每个自然日最多一条，因此直接使用日期 key。
    var id: String { dateKey }
}

/// 管理今日指引文件及其派生页面状态。
///
/// `@MainActor` 保证所有 `@Published` 更新发生在主线程，SwiftUI 可以安全观察。
@MainActor
final class GuidanceStore: ObservableObject {
    // MARK: - 对界面公开的状态

    /// 页面目前应显示哪种顶层状态。外部只能读取，修改集中在 Store 内。
    @Published private(set) var state: GuidanceViewState = .noFile
    /// 文件选择器最近授权的文件名，用于空状态提示。
    @Published private(set) var selectedFileName: String?
    /// 今天的原始文本；编辑页以此初始化草稿。
    @Published private(set) var todayGuidance = ""
    /// 最近 30 个自然日中非空的记录，按日期倒序。
    @Published private(set) var historyEntries: [GuidanceHistoryEntry] = []
    /// 保存失败时由 SwiftUI 绑定为 Alert；保存成功或用户关闭后清空。
    @Published private(set) var saveErrorMessage: String?

    // MARK: - 文件授权与日期工具

    /// Security-scoped bookmark 在 UserDefaults 中的 key。
    private let bookmarkStorageKey = "daily-guidance-file-bookmark"
    /// 从书签恢复出的文件 URL。仅保存普通 URL 不足以跨启动访问沙盒外文件。
    private var selectedFileURL: URL?
    /// JSON key 必须稳定为公历 `yyyy-MM-dd`，不能受用户语言或 12/24 小时设置影响。
    private lazy var dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()

    /// 是否已有可尝试访问的文件。真正权限是否仍有效，要在读写时才能确认。
    var hasSelectedFile: Bool {
        selectedFileURL != nil
    }

    init() {
        // 初始化即恢复书签，让用户不必每次启动都重新选择 iCloud 文件。
        restoreSelectedFile()
    }

    // MARK: - 文件选择与读取

    /// 接收系统文件选择器返回的 URL，并持久化跨启动访问授权。
    ///
    /// Security-scoped URL 只能在 `startAccessing...` 与 `stopAccessing...` 之间使用。
    /// 书签保存的是这份授权的可恢复表示，不是文件内容副本。
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

    /// 从当前文件重新加载全部指引。
    ///
    /// Mac 端或另一台设备可能通过 iCloud 修改同一文件，所以每次 App 回到前台也会调用。
    func refresh() {
        guard let selectedFileURL else {
            todayGuidance = ""
            historyEntries = []
            state = .noFile
            return
        }

        state = .loading

        do {
            // Data 必须在 security-scoped 访问区间内读取。
            let data = try withSecurityScopedAccess(to: selectedFileURL) {
                try Data(contentsOf: selectedFileURL)
            }
            let guidanceByDate = try JSONDecoder().decode([String: String].self, from: data)
            apply(guidanceByDate)
        } catch let error as DecodingError {
            // 解析错误与文件访问错误分开提示，便于用户判断是 JSON 内容还是 iCloud 权限问题。
            todayGuidance = ""
            historyEntries = []
            state = .error("数据文件格式无效：\(decodingErrorDescription(error))")
        } catch {
            todayGuidance = ""
            historyEntries = []
            state = .error("无法读取数据文件，请确认文件仍在 iCloud Drive 中。")
        }
    }

    // MARK: - 保存

    /// 保存指定日期的纯文本，并保留 JSON 中所有其他日期。
    ///
    /// 保存前重新读取磁盘，而不是直接使用内存快照，能尽量保留 Mac 或其他设备刚同步来的更新。
    /// 日期格式会严格校验，避免向文件写入无法在历史时间流中识别的 key。
    ///
    /// - Returns: 写入与状态刷新都成功时返回 `true`，失败详情写入 `saveErrorMessage`。
    @discardableResult
    func saveGuidance(_ guidance: String, forDateKey dateKey: String) -> Bool {
        guard let selectedFileURL else {
            saveErrorMessage = "请先选择 daily-guidance.json。"
            return false
        }
        guard let parsedDate = dateKeyFormatter.date(from: dateKey),
              dateKeyFormatter.string(from: parsedDate) == dateKey else {
            saveErrorMessage = "指引日期格式无效。"
            return false
        }

        do {
            let guidanceByDate = try withSecurityScopedAccess(to: selectedFileURL) {
                // 在授权范围内完成“读-改-写”全过程。
                let data = try Data(contentsOf: selectedFileURL)
                var values = try JSONDecoder().decode([String: String].self, from: data)
                // 只裁掉首尾空白；正文中的换行和缩进保持不变。
                values[dateKey] = guidance.trimmingCharacters(in: .whitespacesAndNewlines)

                let encoder = JSONEncoder()
                // 可读、稳定排序的 JSON 便于用户手工检查，也减少无意义的 diff。
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                var updatedData = try encoder.encode(values)
                updatedData.append(0x0A)
                // 原子写入会先生成临时文件再替换，降低中途失败留下半份 JSON 的风险。
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

    /// 用户关闭错误提示后清空消息，避免 Alert 反复出现。
    func clearSaveError() {
        saveErrorMessage = nil
    }

    /// 忘记当前文件和书签，但不会删除 iCloud 中的文件或内容。
    func forgetSelectedFile() {
        selectedFileURL = nil
        selectedFileName = nil
        todayGuidance = ""
        historyEntries = []
        saveErrorMessage = nil
        UserDefaults.standard.removeObject(forKey: bookmarkStorageKey)
        state = .noFile
    }

    // MARK: - Security-scoped bookmark

    /// 从 UserDefaults 中的书签恢复文件访问。
    ///
    /// iCloud 可能移动或重新下载文件，系统会把书签标记为 stale；此时立即生成新书签，
    /// 避免下一次启动彻底失去授权。
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

    /// 在一个明确作用域内开启文件访问，并确保无论成功或抛错都会关闭访问。
    ///
    /// `rethrows` 表示本函数本身不制造新错误，只把调用方 operation 的错误继续抛出。
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

    // MARK: - 日期与派生状态

    /// 今天在本地时区的零点，供界面显示与比较。
    var todayDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// 今天对应的 JSON key。
    var todayDateKey: String {
        dateKeyFormatter.string(from: Date())
    }

    /// 把完整 JSON 字典转换为 SwiftUI 直接消费的状态。
    private func apply(_ guidanceByDate: [String: String]) {
        let guidance = guidanceByDate[todayDateKey] ?? ""
        saveErrorMessage = nil
        todayGuidance = guidance
        historyEntries = recentHistory(from: guidanceByDate)
        state = guidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .empty
            : .content(guidance)
    }

    /// 生成包含今天在内的最近 30 个自然日非空记录。
    ///
    /// 使用“自然日”而不是 30×24 小时，避免夏令时变化导致边界日期偏移。
    private func recentHistory(from guidanceByDate: [String: String]) -> [GuidanceHistoryEntry] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let today = calendar.startOfDay(for: Date())
        guard let earliestDate = calendar.date(byAdding: .day, value: -29, to: today) else {
            return []
        }

        return guidanceByDate.compactMap { dateKey, guidance in
            // 回写一次字符串用于严格校验，防止 DateFormatter 宽松接受不规范日期。
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

    /// 把技术性的 DecodingError 转换为用户能够处理的中文原因。
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
