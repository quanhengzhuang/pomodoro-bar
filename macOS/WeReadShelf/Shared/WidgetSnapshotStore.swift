import Foundation
#if os(iOS)
import CryptoKit
import ImageIO
import UniformTypeIdentifiers
#endif

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

#if os(iOS)
    private static let maxDownloadBytes = 3 * 1024 * 1024
    private static let maxCoverBytes = 256 * 1024

    static func coverData(for url: URL) -> Data? {
        guard let path = try? coverCacheURL(for: url),
              let file = try? FileHandle(forReadingFrom: path) else { return nil }
        defer { try? file.close() }
        guard let data = try? file.read(upToCount: maxCoverBytes + 1),
              !data.isEmpty, data.count <= maxCoverBytes else { return nil }
        return data
    }

    static func prefetchCovers(for snapshot: ReadingWidgetSnapshot) async -> Bool {
        let missing = Array(coverURLs(in: snapshot).filter { coverData(for: $0) == nil })
        guard !missing.isEmpty, !Task.isCancelled else { return false }

        do {
            var directory = try coverCacheDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? directory.setResourceValues(values)
        } catch {
            return false
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let workers = min(missing.count, 3)
        return await withTaskGroup(of: Bool.self) { group in
            for worker in 0..<workers {
                group.addTask {
                    var didCache = false
                    for index in stride(from: worker, to: missing.count, by: workers) {
                        guard !Task.isCancelled else { break }
                        if await cacheCover(at: missing[index], session: session) { didCache = true }
                    }
                    return didCache
                }
            }
            var didCache = false
            for await result in group {
                if result { didCache = true }
            }
            return didCache
        }
    }

    static func trimCoverCache(keeping snapshot: ReadingWidgetSnapshot) {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        guard let directory = try? coverCacheDirectory(),
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles
              ) else { return }
        let covers: [(path: URL, date: Date)] = files.compactMap { file in
            let key = file.deletingPathExtension().lastPathComponent.utf8
            guard file.pathExtension == "jpg", key.count == 64,
                  key.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
                  let values = try? file.resourceValues(forKeys: resourceKeys),
                  values.isRegularFile == true else { return nil }
            return (file, values.contentModificationDate ?? .distantPast)
        }
        let excess = covers.count - 64
        guard excess > 0, !Task.isCancelled else { return }
        let current = Set(coverURLs(in: snapshot).compactMap { try? coverCacheURL(for: $0) })
        let stale = covers.filter { !current.contains($0.path) }.sorted { $0.date < $1.date }
        for cover in stale.prefix(excess) {
            guard !Task.isCancelled else { return }
            try? FileManager.default.removeItem(at: cover.path)
        }
    }

    private static func coverURLs(in snapshot: ReadingWidgetSnapshot) -> Set<URL> {
        let books = Array(snapshot.recentBooks.prefix(4)) + snapshot.customBooks.prefix(4)
        return Set(books.compactMap(\.coverURL).filter { $0.scheme?.lowercased() == "https" })
    }

    private static func cacheCover(at url: URL, session: URLSession) async -> Bool {
        do {
            let (bytes, response) = try await session.bytes(from: url)
            defer { bytes.task.cancel() }
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode),
                  response.url?.scheme?.lowercased() == "https",
                  response.expectedContentLength <= Int64(maxDownloadBytes) else { return false }
            var data = Data()
            for try await byte in bytes {
                guard data.count < maxDownloadBytes else { return false }
                data.append(byte)
            }
            try Task.checkCancellation()
            guard let thumbnail = thumbnailData(from: data),
                  thumbnail.count <= maxCoverBytes else { return false }
            try Task.checkCancellation()
            try thumbnail.write(to: coverCacheURL(for: url), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func thumbnailData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 300
              ] as CFDictionary) else { return nil }
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? result as Data : nil
    }

    private static func coverCacheDirectory() throws -> URL {
        try snapshotURL().deletingLastPathComponent().appendingPathComponent("widget-covers", isDirectory: true)
    }

    private static func coverCacheURL(for url: URL) throws -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return try coverCacheDirectory().appendingPathComponent(hash + ".jpg", isDirectory: false)
    }
#endif

    private static func snapshotURL() throws -> URL {
        guard let identifier = Bundle.main.object(forInfoDictionaryKey: "WeReadAppGroupIdentifier") as? String,
              !identifier.isEmpty, !identifier.hasPrefix("."),
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        else { throw StorageError.missingSharedContainer }
        return container.appendingPathComponent("reading-widget-snapshot.json", isDirectory: false)
    }
}
