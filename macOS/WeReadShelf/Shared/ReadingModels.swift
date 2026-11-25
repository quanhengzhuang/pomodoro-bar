import Foundation

struct ReadingBook: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let author: String?
    let coverURL: URL?
    let readerURL: URL?
    let detailURL: URL?
    let lastReadAt: Date?
    let isPrivate: Bool

    var destinationURL: URL? { readerURL ?? detailURL }
}

enum ReadingList: String, CaseIterable, Identifiable, Sendable {
    case recent
    case custom

    static let urlScheme = "weread-shelf"

    var id: Self { self }

    var title: String {
        switch self {
        case .recent: "最近阅读"
        case .custom: "自定义书单"
        }
    }

    var iconName: String {
        switch self {
        case .recent: "clock"
        case .custom: "bookmark"
        }
    }

    var widgetKind: String {
        switch self {
        case .recent: "WeReadRecentReading"
        case .custom: "WeReadCustomBookList"
        }
    }

    var openURL: URL { URL(string: "\(Self.urlScheme)://\(rawValue)")! }

    init?(openURL: URL) {
        guard openURL.scheme == Self.urlScheme, let host = openURL.host else { return nil }
        self.init(rawValue: host)
    }
}
