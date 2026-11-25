import Foundation
#if os(iOS)
import SwiftUI
import UIKit

extension Color {
    static let readingShelfBackground = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark { return .secondarySystemBackground }
        return UIColor(red: 244.0 / 255, green: 245.0 / 255, blue: 247.0 / 255, alpha: 1)
    })
}
#endif

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
        case .custom: "我的书单"
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

extension ReadingList {
    func widgetBookURL(for bookID: String) -> URL {
        var components = URLComponents()
        components.scheme = Self.urlScheme
        components.host = "book"
        components.queryItems = [
            URLQueryItem(name: "list", value: rawValue),
            URLQueryItem(name: "id", value: bookID)
        ]
        return components.url ?? openURL
    }
}

struct ReadingWidgetBookLink {
    let list: ReadingList
    let bookID: String

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == ReadingList.urlScheme, components.host == "book",
              components.path.isEmpty, let items = components.queryItems, items.count == 2,
              let listName = items.first(where: { $0.name == "list" })?.value,
              let list = ReadingList(rawValue: listName),
              let bookID = items.first(where: { $0.name == "id" })?.value, !bookID.isEmpty
        else { return nil }
        self.list = list
        self.bookID = bookID
    }
}
