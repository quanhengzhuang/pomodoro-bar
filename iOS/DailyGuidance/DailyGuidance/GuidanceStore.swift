import Combine
import Foundation

enum GuidanceViewState: Equatable {
    case noFile
    case loading
    case content(String)
    case empty
    case error(String)
}

@MainActor
final class GuidanceStore: ObservableObject {
    @Published private(set) var state: GuidanceViewState = .noFile
    @Published private(set) var selectedFileName: String?

    private let bookmarkStorageKey = "daily-guidance-file-bookmark"
    private var selectedFileURL: URL?

    var hasSelectedFile: Bool {
        selectedFileURL != nil
    }

    init() {
        restoreSelectedFile()
    }

    func selectFile(_ url: URL) {
        do {
            let bookmark = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: bookmarkStorageKey)
            selectedFileURL = url
            selectedFileName = url.lastPathComponent
            refresh()
        } catch {
            state = .error("无法保存文件访问权限，请重新选择数据文件。")
        }
    }

    func refresh() {
        guard let selectedFileURL else {
            state = .noFile
            return
        }

        state = .loading
        let didStartAccessing = selectedFileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                selectedFileURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: selectedFileURL)
            let guidanceByDate = try JSONDecoder().decode([String: String].self, from: data)
            let guidance = guidanceByDate[todayDateKey] ?? ""
            state = guidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? .empty
                : .content(guidance)
        } catch let error as DecodingError {
            state = .error("数据文件格式无效：\(decodingErrorDescription(error))")
        } catch {
            state = .error("无法读取数据文件，请确认文件仍在 iCloud Drive 中。")
        }
    }

    func forgetSelectedFile() {
        selectedFileURL = nil
        selectedFileName = nil
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
                let renewedBookmark = try url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                UserDefaults.standard.set(renewedBookmark, forKey: bookmarkStorageKey)
            }
            refresh()
        } catch {
            forgetSelectedFile()
            state = .error("之前选择的数据文件已无法访问，请重新选择。")
        }
    }

    private var todayDateKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
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
