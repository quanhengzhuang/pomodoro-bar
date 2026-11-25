import Foundation

struct ReadingWidgetSnapshot: Codable, Sendable {
    let recentBooks: [ReadingBook]
    let customBooks: [ReadingBook]
    let lastSyncedAt: Date?

    static let empty = Self(recentBooks: [], customBooks: [], lastSyncedAt: nil)
}

enum WidgetSnapshotStore {
    private enum StorageError: Error {
        case missingSharedContainer
    }

    static func load() -> ReadingWidgetSnapshot {
        guard let url = try? snapshotURL(),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(ReadingWidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    static func save(_ snapshot: ReadingWidgetSnapshot) throws {
        let url = try snapshotURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: url, options: .atomic)
    }

    private static func snapshotURL() throws -> URL {
        guard let identifier = Bundle.main.object(forInfoDictionaryKey: "WeReadAppGroupIdentifier") as? String,
              !identifier.isEmpty, !identifier.hasPrefix("."),
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        else { throw StorageError.missingSharedContainer }
        return container.appendingPathComponent("reading-widget-snapshot.json", isDirectory: false)
    }
}
